//
//  NetworkError-Retries.swift
//  Alley
//
//  Copyright © 2019 Radiant Tap
//  MIT License · http://choosealicense.com/licenses/mit/
//

import Foundation

extension NetworkError {
	///	Returns `true` if URLRequest should be retried for the given `NetworkError` instance.
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
