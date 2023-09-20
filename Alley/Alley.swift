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
	public func alleyData(for urlRequest: URLRequest, maxRetries: Int = 10, allowEmptyData: Bool = false) async throws -> Data {
		let networkRequest = RetriableRequest(
			urlRequest,
			1,
			maxRetries,
			allowEmptyData
		)
		
		return try await execute(networkRequest)
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
	func execute(_ networkRequest: RetriableRequest) async throws -> Data {
		let urlRequest = networkRequest.urlRequest
		
		do {
			let (data, urlResponse) = try await data(for: urlRequest)
			try verify(data, urlResponse, for: networkRequest)
			return data
			
		} catch let err as NetworkError {
			return try await retry(networkRequest, ifPossibleFor: err)

		} catch let err as URLError {
			return try await retry(networkRequest, ifPossibleFor: NetworkError.urlError(err))

		} catch let err {
			return try await retry(networkRequest, ifPossibleFor: NetworkError.generalError(err))
		}
	}

	///
	func verify(_ data: Data, _ urlResponse: URLResponse, for networkRequest: RetriableRequest) throws {
	
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
	func retry(_ networkRequest: RetriableRequest, ifPossibleFor err: NetworkError) async throws -> Data {
		guard err.shouldRetry else {
			throw err
		}

		//	update retries count
		var newRequest = networkRequest
		newRequest.currentRetries += 1
		
		if newRequest.currentRetries >= newRequest.maxRetries {
			throw NetworkError.inaccessible
		}
		
		if err.retryInterval > 0 {
			try await Task.sleep(nanoseconds: UInt64(err.retryInterval * 1_000_000_000))
		}

		return try await execute(newRequest)
	}
}
