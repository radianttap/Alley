//
//  NetworkError-Localized.swift
//  Alley
//
//  Copyright © 2019 Radiant Tap
//  MIT License · http://choosealicense.com/licenses/mit/
//

import Foundation

extension NetworkError: LocalizedError {
	public var errorDescription: String? {
		switch self {
			case .generalError(let error):
				return error.localizedDescription
				
			case .urlError(let urlError):
				return urlError.localizedDescription
				
			case .invalidResponseType, .noResponse:
				return NSLocalizedString("Internal error", comment: "")
				
			case .noResponseData:
				return nil
				
			case .endpointError(let httpURLResponse, _):
				let s = "\( httpURLResponse.statusCode ) \( HTTPURLResponse.localizedString(forStatusCode: httpURLResponse.statusCode) )"
				return s
				
			case .inaccessible:
				return NSLocalizedString("Service is not accessible", comment: "")
		}
	}
	
	public var failureReason: String? {
		switch self {
			case .generalError(let error):
				return (error as NSError).localizedFailureReason
				
			case .urlError(let urlError):
				return (urlError as NSError).localizedFailureReason
				
			case .noResponse:
				return NSLocalizedString("Request apparently succeeded (no errors) but URLResponse was not received.", comment: "")
				
			case .invalidResponseType(let response):
				return String(format: NSLocalizedString("Response is not HTTP response.\n\n%@", comment: ""), response)
				
			case .inaccessible:
				return nil
				
			case .noResponseData:
				return NSLocalizedString("Request succeeded, no response body received", comment: "")
				
			case .endpointError(let httpURLResponse, let data):
				let s = "\( httpURLResponse.formattedHeaders )\n\n\( data?.utf8StringRepresentation ?? "" )"
				return s
		}
	}
}

private extension HTTPURLResponse {
	var formattedHeaders: String {
		return allHeaderFields.map { "\( $0.key ) : \( $0.value )" }.joined(separator: "\n")
	}
}

private extension Data {
	var utf8StringRepresentation: String? {
		guard
			let str = String(data: self, encoding: .utf8)
		else { return nil }
		
		return str
	}
}
