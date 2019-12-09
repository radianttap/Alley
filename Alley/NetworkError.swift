//
//  NetworkError.swift
//  Alley
//
//  Copyright © 2019 Radiant Tap
//  MIT License · http://choosealicense.com/licenses/mit/
//

import Foundation

/**
Declaration of errors that Alley can throw/return.

Since this is all about networking, it should pass-through any URLErrors that happen but also add its own
*/
enum NetworkError: Error {
	///	URLSession errors are passed-through, handle as appropriate
	case urlError(URLError)

	///	When no URLResponse is returned but also no URLError
	case noResponse

	///	When URLResponse is not `HTTPURLResponse`
	case invalidResponseType(URLResponse)

	///	Status code is in 200...299 range, but response body is empty. This can be both valid and invalid, depending on HTTP method and specific API
	case noResponseData(HTTPURLResponse)

	case inaccessible //	when network conditions are so bad a max number of network retries fails

	///	URLSession returned an `Error` object which is not `URLError`
	case generalError(Swift.Error)
}



private extension Data {
	var utf8StringRepresentation: String? {
		guard
			let str = String(data: self, encoding: .utf8)
			else { return nil }

		return str
	}
}
