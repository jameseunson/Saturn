//
//  LoginAuthenticationInteractor.swift
//  Saturn
//
//  Created by James Eunson on 17/3/2023.
//

import Foundation
import Factory

final class LoginAuthenticationInteractor: Interactor {
    @Injected(\.keychainWrapper) private var keychainWrapper
    @Injected(\.htmlApiManager) private var htmlApiManager
    
    @Published var isLoading: Bool = false
    
    init(isLoading: Bool = false) {
        self.isLoading = isLoading
    }
    
    override func didBecomeActive() {
        super.didBecomeActive()
        
        HTTPCookieStorage.shared.removeCookies(since: .distantPast)
    }
    
    func login(with username: String, password: String) async throws -> Bool {
        defer {
            DispatchQueue.main.async { [weak self] in self?.isLoading = false }
        }
        DispatchQueue.main.async { [weak self] in self?.isLoading = true }
        return try await htmlApiManager.login(with: username, password: password)
    }
}

final class LoginAuthenticationURLSessionDelegate: NSObject, URLSessionTaskDelegate, URLSessionDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        /// Disable auto-follow of 302 redirects, which causes us to lose access to the cookie
        completionHandler(nil)
    }
}

extension URLRequest {
    mutating func addDefaultHeaders() {
        addValue("https://news.ycombinator.com", forHTTPHeaderField: "Origin")
        addValue("https://news.ycombinator.com", forHTTPHeaderField: "Referer")
        addValue("news.ycombinator.com", forHTTPHeaderField: "Host")
        addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
    }
    
    mutating func addFormHeaders(postBody: String) {
        httpBody = postBody.data(using: .utf8)
        addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    }
}
