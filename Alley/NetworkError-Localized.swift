//
//  NetworkError-Localized.swift
//  Alley
//
//  Copyright © 2019 Radiant Tap
//  MIT License · http://choosealicense.com/licenses/mit/
//

import Foundation

extension NetworkError: LocalizedError {
	var errorDescription: String? {
		switch self {
		case .generalError(let error):
			return error.localizedDescription

		case .urlError(let urlError):
			return urlError.localizedDescription

		case .invalidResponseType:
			return NSLocalizedString("Internal error", comment: "")

        case .noResponseData:
            return nil

		case .unavailable:
			return NSLocalizedString("Service is not accessible", comment: "")
		}
	}

	var failureReason: String? {
		switch self {
		case .generalError(let error):
			return (error as NSError).localizedFailureReason

		case .urlError(let urlError):
			return (urlError as NSError).localizedFailureReason

		case .invalidResponseType(let response):
			return String(format: NSLocalizedString("Response is not HTTP response.\n\n%@", comment: ""), response)

		case .unavailable:
			return nil

        case .noResponseData:
            return NSLocalizedString("Request succeeded, no response body received", comment: "")
		}
	}
}