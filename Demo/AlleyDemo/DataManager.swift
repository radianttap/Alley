//
//  DataManager.swift
//  AlleyDemo
//
//  Created by Aleksandar Vacić on 12/11/19.
//  Copyright © 2019 Radiant Tap. All rights reserved.
//

import Foundation
import Alley

@MainActor
final class DataManager: ObservableObject {
	@Published private(set) var zens: [String] = []

	private lazy var urlSession: URLSession = prepareSession()
}

//	MARK: Old-school

extension DataManager {
	func startFetching() {
		fetch()
	}
	
	private func fetch() {
		let urlRequest = URLRequest(url: URL(string: "https://api.github.com/zen")!)
		
		urlSession.performNetworkRequest(urlRequest, maxRetries: 3) {
			[unowned self] dataResult in
			
			switch dataResult {
				case .success(let data):
					if let s = data.utf8StringRepresentation {
						DispatchQueue.main.async {
							self.zens.append(s)
						}
					}
					
				case .failure(let networkError):
					print(networkError)
			}
			
			self.schedule()
		}
	}
	
	private func schedule() {
		DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
			[unowned self] in
			
			self.fetch()
		}
	}
}
	
//	MARK: Async / Await

extension DataManager {
	func startFetchingAsyncAwait() {
		Task {
			await fetchAsyncAwait()
		}
	}
	
	func fetchAsyncAwait() async {
		let urlRequest = URLRequest(url: URL(string: "https://api.github.com/zen")!)

		do {
			let data = try await urlSession.alleyData(for: urlRequest, maxRetries: 3)
			if let s = data.utf8StringRepresentation {
				self.zens.append(s)
			}

		} catch let networkError {
			print(networkError)
		}
		
		await scheduleAsyncAwait()
	}
	
	private func scheduleAsyncAwait() async {
		try? await Task.sleep(nanoseconds: UInt64(3 * 1_000_000_000))
		await fetchAsyncAwait()
	}
}

//	MARK: Internals

private extension DataManager {
	func prepareSession() -> URLSession {
		let urlSessionConfiguration: URLSessionConfiguration = {
			let c = URLSessionConfiguration.default
			c.allowsCellularAccess = true
			c.httpCookieAcceptPolicy = .never
			c.httpShouldSetCookies = false
			c.requestCachePolicy = .reloadIgnoringLocalCacheData
			return c
		}()

		return URLSession(configuration: urlSessionConfiguration,
						  delegate: nil,
						  delegateQueue: nil)
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
