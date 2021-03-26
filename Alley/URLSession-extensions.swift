//
//  URLSession-Extensions.swift
//  Alley
//
//  Copyright © 2019 Radiant Tap
//  MIT License · http://choosealicense.com/licenses/mit/
//

import Foundation

extension URLSession {
	///	Helper type which groups input, output and metadata for one singular network call.
	///
	///	- `URLRequest` (input)
	///	- `NetworkCallback` from the caller (output)
	///	along with helpful processing properties, like number of retries.
	public typealias NetworkRequest = (
		urlRequest: URLRequest,
		currentRetries: Int,
		maxRetries: Int,
		allowEmptyData: Bool,
		callback: NetworkCallback
	)

	///	Output types
	public typealias NetworkResult = Result<Data, NetworkError>
	public typealias NetworkCallback = (NetworkResult) -> Void

	/// Executes given URLRequest instance, possibly retrying the said number of times. Through `callback` returns either `Data` from the response or `NetworkError` instance.
	/// If any authentication needs to be done, it's handled internally by this methods and its derivatives.
	/// - Parameters:
	///   - urlRequest: URLRequest instance to execute.
	///   - maxRetries: Number of automatic retries (default is 10).
	///   - allowEmptyData: Should empty response `Data` be treated as failure (this is default) even if no other errors are returned by URLSession. Default is `false`.
	///   - callback: Closure to return the result of the request's execution.
	public func performNetworkRequest(
		_ urlRequest: URLRequest,
		maxRetries: Int = 10,
		allowEmptyData: Bool = false,
		callback: @escaping NetworkCallback)
	{
		if maxRetries <= 0 {
			preconditionFailure("maxRetries must be 1 or larger.")
		}

		let networkRequest = NetworkRequest(
			urlRequest,
			1,
			maxRetries,
			allowEmptyData,
			callback
		)

		//	now execute the request
		execute(networkRequest)
	}
}

private extension URLSession {
	///	Creates the instance of `URLSessionDataTask`, performs it then lightly processes the response before calling `validate`.
	func execute(_ networkRequest: NetworkRequest) {
		let urlRequest = networkRequest.urlRequest

		let task = dataTask(with: urlRequest) {
			[unowned self] data, urlResponse, error in

			let dataResult = self.process(data, urlResponse, error, for: networkRequest)
			self.validate(dataResult, for: networkRequest)
		}

		task.resume()
	}

	///	Process results of `URLSessionDataTask` and converts it into `DataResult` instance
	func process(_ data: Data?, _ urlResponse: URLResponse?, _ error: Error?, for networkRequest: NetworkRequest) -> NetworkResult {
		let allowEmptyData = networkRequest.allowEmptyData

		if let urlError = error as? URLError {
			return .failure( NetworkError.urlError(urlError) )

		} else if let otherError = error {
			return .failure( NetworkError.generalError(otherError) )
		}

		guard let httpURLResponse = urlResponse as? HTTPURLResponse else {
			if let urlResponse = urlResponse {
				return .failure( NetworkError.invalidResponseType(urlResponse) )
			} else {
				return .failure( NetworkError.noResponse )
			}
		}

		if httpURLResponse.statusCode >= 400 {
			return .failure( NetworkError.endpointError(httpURLResponse, data) )
		}

		guard let data = data, !data.isEmpty else {
			if allowEmptyData {
				return .success(Data())
			}

			return .failure( NetworkError.noResponseData(httpURLResponse) )
		}

		return .success(data)
	}

	///	Checks the result of `URLSessionDataTask` and if there were errors, should the `URLRequest` be retried.
	func validate(_ result: NetworkResult, for networkRequest: NetworkRequest) {
		let callback = networkRequest.callback

		switch result {
			case .success:
				break

			case .failure(let networkError):
				if networkError.shouldRetry {
					//	update retries count
					var newRequest = networkRequest
					newRequest.currentRetries += 1

					if newRequest.currentRetries >= newRequest.maxRetries {
						callback(.failure(.inaccessible))
						return
					}

					//	try again
					self.execute(newRequest)
					return
				}
		}

		callback(result)
	}
}
