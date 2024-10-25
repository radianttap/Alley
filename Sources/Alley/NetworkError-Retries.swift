//
//  NetworkError-Retries.swift
//  Alley
//
//  Copyright © 2019 Radiant Tap
//  MIT License · http://choosealicense.com/licenses/mit/
//

import Foundation

public extension NetworkError {
	///	Returns `true` if `URLRequest` should be retried for the given `NetworkError` instance.
	///
	///	At the lowest network levels, it makes sense to retry for cases of (possible) temporary outage. Things like timeouts, can't connect to host, network connection lost.
	///	In mobile context, this can happen as you move through the building or traffic and may not represent serious or more permanent connection issues.
	///
	///	Upper layers of the app architecture may build on this to add more specific cases when the request should be retried.
	var shouldRetry: Bool {
		switch self {
			case .urlError(let urlError):
				//	if temporary network issues, retry
				switch urlError.code {
					case .timedOut,
							.cannotFindHost,
							.cannotConnectToHost,
							.networkConnectionLost,
							.dnsLookupFailed,
							.notConnectedToInternet:
						return true
						
					default:
						break
				}
				
			case .endpointError(let httpURLResponse, _):
				switch httpURLResponse.statusCode {
					case 408,	// Request Timeout
						444,	// Connection Closed Without Response
						503,	// Service Unavailable
						504,	// Gateway Timeout
						599:	// Network Connect Timeout Error
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
