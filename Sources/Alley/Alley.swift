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
	/// - Parameter retryInterval: Base delay (seconds) used for exponential backoff between retries. Actual wait is `retryInterval * 2^(attempt-1)`, capped at 30s, with full random jitter in `[0, cap]`. Pass `0` to retry immediately.
	public func alleyData(for urlRequest: URLRequest, maxRetries: Int = 10, retryInterval: TimeInterval = 0.5, allowEmptyData: Bool = false) async throws(NetworkError) -> Data {
		let networkRequest = RetriableRequest(
			urlRequest,
			1,
			maxRetries,
			allowEmptyData
		)
		
		return try await execute(networkRequest, retryInterval: retryInterval)
	}
}

@available(macOS 12, iOS 15, watchOS 10.0, tvOS 15, visionOS 1, *)
private extension URLSession {

	typealias RetriableRequest = (
		urlRequest: URLRequest,
		currentRetries: Int,
		maxRetries: Int,
		allowEmptyData: Bool
	)

	///
	func execute(_ networkRequest: RetriableRequest, retryInterval: TimeInterval) async throws(NetworkError) -> Data {
		let urlRequest = networkRequest.urlRequest
		
		do {
			let (data, urlResponse) = try await data(for: urlRequest)
			try verify(data, urlResponse, for: networkRequest, retryInterval: retryInterval)
			return data
			
		} catch let err as NetworkError {
			return try await retry(networkRequest, ifPossibleFor: err, retryInterval: retryInterval)

		} catch let err as URLError {
			return try await retry(networkRequest, ifPossibleFor: NetworkError.urlError(err), retryInterval: retryInterval)

		} catch let err {
			return try await retry(networkRequest, ifPossibleFor: NetworkError.generalError(err), retryInterval: retryInterval)
		}
	}

	///
	func verify(_ data: Data, _ urlResponse: URLResponse, for networkRequest: RetriableRequest, retryInterval: TimeInterval) throws(NetworkError) {
	
		guard let httpURLResponse = urlResponse as? HTTPURLResponse else {
			throw NetworkError.invalidResponseType(urlResponse)
		}
		
		if httpURLResponse.statusCode >= 400 {
			throw NetworkError.endpointError(httpURLResponse, data)
		}
		
		if data.isEmpty, !networkRequest.allowEmptyData {
			throw NetworkError.noResponseData(httpURLResponse)
		}
	}
	
	///
	func retry(_ networkRequest: RetriableRequest, ifPossibleFor err: NetworkError, retryInterval: TimeInterval) async throws(NetworkError) -> Data {
		guard err.shouldRetry else {
			throw err
		}

		//	update retries count
		var newRequest = networkRequest
		newRequest.currentRetries += 1
		
		if newRequest.currentRetries >= newRequest.maxRetries {
			throw NetworkError.inaccessible
		}
		
		if retryInterval > 0 {
			let delay = backoffDelay(base: retryInterval, attempt: newRequest.currentRetries)
			do {
				try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
			} catch {
				//	if Task.sleep fails for whatever impossible reason,
				//	then return our last NetworkError instance
				throw err
			}
		}

		return try await execute(newRequest, retryInterval: retryInterval)
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
