//
//  URLSession-Extensions.swift
//  Alley
//
//  Copyright © 2019 Radiant Tap
//  MIT License · http://choosealicense.com/licenses/mit/
//

import Foundation

@available(macOS 12, iOS 15, watchOS 10.0, tvOS 15, visionOS 1, *)
extension URLSession {
	/// Executes given `URLRequest` instance, possibly retrying the said number of times. Returns `Data` from the response or throws some `NetworkError` instance.
	///
	/// If any authentication needs to be done, it's handled internally by this methods and its derivatives.
	///
	/// - Parameters:
	///   - urlRequest: `URLRequest` instance to execute.
	///   - maxRetries: Number of automatic retries (default is 10).
	///   - allowEmptyData: Should empty response `Data` be treated as failure (this is default) even if no other errors are returned by `URLSession`. Default is `false`.
	///   - retryNonIdempotent: If `true`, retry even when the HTTP method is not idempotent (e.g. `POST`, `PATCH`). Default is `false` to avoid accidentally submitting the same payload twice. Only enable when the server-side operation is safe to repeat.
	/// - Parameter retryInterval: Base delay (seconds) used for exponential backoff between retries. Actual wait is `retryInterval * 2^(attempt-1)`, capped at 30s, with full random jitter in `[0, cap]`. Pass `0` to retry immediately.
	public func alleyData(for urlRequest: URLRequest, maxRetries: Int = 10, retryInterval: TimeInterval = 0.5, allowEmptyData: Bool = false, retryNonIdempotent: Bool = false) async throws(NetworkError) -> Data {
		let networkRequest = RetriableRequest(urlRequest, 1, maxRetries, retryNonIdempotent)
		let (data, httpURLResponse) = try await execute(networkRequest, retryInterval: retryInterval) { urlRequest in
			try await self.data(for: urlRequest)
		}
		if data.isEmpty, !allowEmptyData {
			throw NetworkError.noResponseData(httpURLResponse)
		}
		return data
	}

	///	Downloads the response body to a temporary file, reusing Alley's retry machinery. Returns the file URL and the `HTTPURLResponse`.
	///
	///	The file at the returned URL is valid only within the caller's execution context; move or read it before the scope ends, just like with `URLSession.download(for:)`.
	///	When a retry occurs, the previous attempt's temporary file is discarded — this method does not use `URLSession` resume data, so each retry starts a fresh download.
	///
	/// - Parameters:
	///   - urlRequest: `URLRequest` instance to execute.
	///   - maxRetries: Number of automatic retries (default is 10).
	///   - retryInterval: Base delay (seconds) used for exponential backoff between retries.
	///   - retryNonIdempotent: See `alleyData(for:...)`.
	public func alleyDownload(for urlRequest: URLRequest, maxRetries: Int = 10, retryInterval: TimeInterval = 0.5, retryNonIdempotent: Bool = false) async throws(NetworkError) -> (URL, HTTPURLResponse) {
		let networkRequest = RetriableRequest(urlRequest, 1, maxRetries, retryNonIdempotent)
		return try await execute(networkRequest, retryInterval: retryInterval) { urlRequest in
			try await self.download(for: urlRequest)
		}
	}

	///	Uploads `bodyData` using the given request (method typically `POST` or `PUT`) and returns the response `Data`, reusing Alley's retry machinery.
	///
	///	Upload requests are almost always non-idempotent. The default is to not retry on transient failures; pass `retryNonIdempotent: true` only when the server treats the upload as idempotent (e.g. via an `Idempotency-Key` header).
	///
	/// - Parameters:
	///   - urlRequest: `URLRequest` instance to execute. Typically carries `POST` or `PUT`.
	///   - bodyData: Request body to upload. Overrides any body already set on `urlRequest`.
	///   - maxRetries: Number of automatic retries (default is 10).
	///   - retryInterval: Base delay (seconds) used for exponential backoff between retries.
	///   - allowEmptyData: See `alleyData(for:...)`.
	///   - retryNonIdempotent: See `alleyData(for:...)`.
	public func alleyUpload(for urlRequest: URLRequest, from bodyData: Data, maxRetries: Int = 10, retryInterval: TimeInterval = 0.5, allowEmptyData: Bool = false, retryNonIdempotent: Bool = false) async throws(NetworkError) -> Data {
		let networkRequest = RetriableRequest(urlRequest, 1, maxRetries, retryNonIdempotent)
		let (data, httpURLResponse) = try await execute(networkRequest, retryInterval: retryInterval) { urlRequest in
			try await self.upload(for: urlRequest, from: bodyData)
		}
		if data.isEmpty, !allowEmptyData {
			throw NetworkError.noResponseData(httpURLResponse)
		}
		return data
	}
}

@available(macOS 12, iOS 15, watchOS 10.0, tvOS 15, visionOS 1, *)
private extension URLSession {

	typealias RetriableRequest = (
		urlRequest: URLRequest,
		currentRetries: Int,
		maxRetries: Int,
		retryNonIdempotent: Bool
	)

	///	Performs `transport` against the retry state machine. `Payload` is whatever `URLSession` returned alongside the `URLResponse` — `Data`, `URL`, or anything else that fits the same pattern.
	func execute<Payload: Sendable>(
		_ networkRequest: RetriableRequest,
		retryInterval: TimeInterval,
		transport: (URLRequest) async throws -> (Payload, URLResponse)
	) async throws(NetworkError) -> (Payload, HTTPURLResponse) {
		if Task.isCancelled {
			throw NetworkError.cancelled
		}

		do {
			let (payload, urlResponse) = try await transport(networkRequest.urlRequest)
			guard let httpURLResponse = urlResponse as? HTTPURLResponse else {
				throw NetworkError.invalidResponseType(urlResponse)
			}
			if httpURLResponse.statusCode >= 400 {
				//	For non-Data payloads (downloads) the body isn't readily available here;
				//	pass nil rather than blocking to read the file just for the error case.
				throw NetworkError.endpointError(httpURLResponse, payload as? Data)
			}
			return (payload, httpURLResponse)

		} catch let err as NetworkError {
			return try await retry(networkRequest, ifPossibleFor: err, retryInterval: retryInterval, transport: transport)

		} catch let err as URLError {
			//	URLSession surfaces Task cancellation as URLError.cancelled — map it to our
			//	dedicated case so callers can distinguish intentional cancellation from a transport failure.
			if err.code == .cancelled {
				throw NetworkError.cancelled
			}
			return try await retry(networkRequest, ifPossibleFor: NetworkError.urlError(err), retryInterval: retryInterval, transport: transport)

		} catch is CancellationError {
			throw NetworkError.cancelled

		} catch let err {
			return try await retry(networkRequest, ifPossibleFor: NetworkError.generalError(err), retryInterval: retryInterval, transport: transport)
		}
	}

	func retry<Payload: Sendable>(
		_ networkRequest: RetriableRequest,
		ifPossibleFor err: NetworkError,
		retryInterval: TimeInterval,
		transport: (URLRequest) async throws -> (Payload, URLResponse)
	) async throws(NetworkError) -> (Payload, HTTPURLResponse) {
		guard err.shouldRetry else {
			throw err
		}

		//	Refuse to retry non-idempotent methods by default: replaying a POST/PATCH
		//	after networkConnectionLost can double-submit orders, payments, messages, etc.
		//	The original request may have reached the server even though we didn't see the response.
		if !networkRequest.retryNonIdempotent, !isIdempotent(networkRequest.urlRequest.httpMethod) {
			throw err
		}

		//	update retries count
		var newRequest = networkRequest
		newRequest.currentRetries += 1

		if newRequest.currentRetries >= newRequest.maxRetries {
			throw NetworkError.inaccessible
		}

		//	Server-specified Retry-After overrides our backoff when present;
		//	it represents the server's own recovery estimate and should be honored.
		let delay = retryAfterDelay(for: err)
			?? (retryInterval > 0 ? backoffDelay(base: retryInterval, attempt: newRequest.currentRetries) : 0)
		if delay > 0 {
			do {
				try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
			} catch {
				//	Task.sleep only throws on cancellation; propagate that rather than
				//	masking it with the last network error so callers see the real reason we stopped.
				throw NetworkError.cancelled
			}
		}

		return try await execute(newRequest, retryInterval: retryInterval, transport: transport)
	}

	///	RFC 7231 §4.2.2: `GET`, `HEAD`, `OPTIONS`, `TRACE`, `PUT`, `DELETE` are idempotent.
	///	A missing method defaults to `GET`.
	func isIdempotent(_ method: String?) -> Bool {
		guard let method else { return true }
		switch method.uppercased() {
			case "GET", "HEAD", "OPTIONS", "TRACE", "PUT", "DELETE":
				return true
			default:
				return false
		}
	}

	///	Returns the delay requested by the server via the `Retry-After` response header,
	///	or `nil` if the error isn't an endpoint error or the header is absent/unparseable.
	///
	///	Per RFC 7231, `Retry-After` is either a non-negative integer number of seconds or an HTTP-date.
	///	Common on `429 Too Many Requests` and `503 Service Unavailable`.
	func retryAfterDelay(for err: NetworkError) -> TimeInterval? {
		guard case .endpointError(let response, _) = err else { return nil }
		guard let raw = response.value(forHTTPHeaderField: "Retry-After")?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else {
			return nil
		}
		if let seconds = TimeInterval(raw), seconds >= 0 {
			return seconds
		}
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.timeZone = TimeZone(identifier: "GMT")
		formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
		if let date = formatter.date(from: raw) {
			return max(0, date.timeIntervalSinceNow)
		}
		return nil
	}

	///	Full-jitter exponential backoff (AWS Architecture Blog).
	///
	///	Returns a uniformly random delay in `[0, min(cap, base * 2^(attempt-2))]`, so the first
	///	retry waits up to `base`, the second up to `2 * base`, etc., capped at 30 seconds.
	///	Jitter spreads concurrent retriers to prevent synchronized thundering herds against the server.
	func backoffDelay(base: TimeInterval, attempt: Int) -> TimeInterval {
		let cap: TimeInterval = 30
		let exponent = max(0, attempt - 2)
		let ceiling = min(cap, base * pow(2.0, Double(exponent)))
		guard ceiling > 0 else { return 0 }
		return TimeInterval.random(in: 0...ceiling)
	}
}
