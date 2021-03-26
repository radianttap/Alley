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
public enum NetworkError: Error {
	///	When network conditions are so bad that after `maxRetries` the request did not succeed.
	case inaccessible
	
	///	`URLSession` errors are passed-through, handle as appropriate.
	case urlError(URLError)
	
	///	URLSession returned an `Error` object which is not `URLError`
	case generalError(Swift.Error)
	
	///	When no `URLResponse` is returned but also no `URLError` or any other `Error` instance.
	case noResponse
	
	///	When `URLResponse` is not `HTTPURLResponse`.
	case invalidResponseType(URLResponse)
	
	///	Status code is in `200...299` range, but response body is empty. This can be both valid and invalid, depending on HTTP method and/or specific behavior of the service being called.
	case noResponseData(HTTPURLResponse)
	
	///	Status code is `400` or higher thus return the entire `HTTPURLResponse` and `Data` so caller can figure out what happened.
	case endpointError(HTTPURLResponse, Data?)
}
