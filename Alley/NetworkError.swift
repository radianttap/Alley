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

	///	When URLResponse is not `HTTPURLResponse`
	case invalidResponseType(URLResponse)

	///	Status code is in 200...299 range, but response body is empty. This can be both valid and invalid, depending on HTTP method and specific API
	case noResponseData(HTTPURLResponse)

	case unavailable //	when network conditions are so bad a max number of network retries fails

	///	URLSession returned an `Error` object which is not `URLError`
	case generalError(Swift.Error)
}

extension AnnanowError {
    init(httpURLResponse: HTTPURLResponse, data: Data?, endpoint: AnnanowEndpoint) {
		//	the most generic error
		self = .unexpectedResponse(httpURLResponse, data?.utf8StringRepresentation)

		if let data = data, data.count > 0 {
			//	try to convert error message body into specific error
			do {
				let responseError: AnnanowResponseError = try data.decoded()

                switch endpoint {
                case .login:
                    self = .invalidUserCredentials
                    return

                case .mandatoryUpdate:
                    switch httpURLResponse.statusCode {
                    case 400:
                        // Mandatory update error have status code 400 and response body
                        self = .mandatoryUpdate(responseError)
                        return
                    case 409:
                        // App versions currently in development are not added to LIVE backend database
                        self = .unknownAppVersion(Annanow.userAgent)
                        return
                    default:
                        break
                    }
                case .createOrder:
                    self = .outRangeLocation(responseError)
                    return
                    
                case .releasePendingOrder(_, _):
                    switch responseError.data?.dialogType {
                    case .shopWorkingHoursClosed:
                        self = .shopWorkingHoursClosed(responseError)
                        
                    case .partnerWorkingHoursClosed:
                        self = .partnerWorkingHoursClosed(responseError)
                        
                    default:
                        self = .releasePendingOrderError(responseError)
                    }
                    return
                default:
                    break
                }
                self = .apiError(responseError)

            } catch let error {
				log(level: .warning, "Failed to convert error message body: \( data.utf8StringRepresentation ?? "" )\n\( error )")
			}
			return
		}

		//	try to figure out at least something
		switch httpURLResponse.statusCode {
        case 500...599:
            self = .unavailable

		case 401:	//Unauthorized
			self = .unauthorized

		case 403:	//	Forbidden
			self = .forbidden

		default:
			break
		}
	}
}


extension AnnanowError {
	var shouldRetry: Bool {
		switch self {
		case .urlError(let urlError):
			//	if temporary network issues, retry
			switch urlError.code {
			case URLError.timedOut,
				 URLError.cannotFindHost,
				 URLError.cannotConnectToHost,
				 URLError.networkConnectionLost,
				 URLError.dnsLookupFailed:
				return true
			default:
				break
			}
		default:
			break
		}

		return false
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
