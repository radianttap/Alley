//
//  URLSession-Extensions.swift
//  Alley
//
//  Copyright © 2019 Radiant Tap
//  MIT License · http://choosealicense.com/licenses/mit/
//

import Foundation

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension URLSession {
	/// Executes given `URLRequest` instance, possibly retrying the said number of times. Returns `Data` from the response or throws some `NetworkError` instance.
	///
	/// If any authentication needs to be done, it's handled internally by this methods and its derivatives.
	///
	/// - Parameters:
	///   - urlRequest: `URLRequest` instance to execute.
	///   - maxRetries: Number of automatic retries (default is 10).
	///   - allowEmptyData: Should empty response `Data` be treated as failure (this is default) even if no other errors are returned by `URLSession`. Default is `false`.
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

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
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
			do {
				try await Task.sleep(nanoseconds: UInt64(retryInterval * 1_000_000_000))
			} catch {
				//	if Task.sleep fails for whatever impossible reason,
				//	then return our last NetworkError instance
				throw err
			}
		}

		return try await execute(newRequest, retryInterval: retryInterval)
	}
}
