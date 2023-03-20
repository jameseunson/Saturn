//
//  LoginAuthenticationInteractor.swift
//  Saturn
//
//  Created by James Eunson on 17/3/2023.
//

import Foundation

final class LoginAuthenticationInteractor: Interactor {
    let delegate = LoginAuthenticationURLSessionDelegate()
    lazy var urlSession = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
    
    @Published var isLoading: Bool = false
    
    init(isLoading: Bool = false) {
        self.isLoading = isLoading
    }
    
    override func didBecomeActive() {
        super.didBecomeActive()
        
        HTTPCookieStorage.shared.removeCookies(since: .distantPast)
    }
    
    func login(with username: String, password: String) async throws -> Bool {
        guard let url = URL(string: "https://news.ycombinator.com/login"),
              !username.isEmpty,
              !password.isEmpty else {
            throw LoginError.generic
        }
        
        DispatchQueue.main.async { [weak self] in self?.isLoading = true }
        defer {
            DispatchQueue.main.async { [weak self] in self?.isLoading = false }
        }
        
        var mutableRequest = URLRequest(url: url)
        mutableRequest.httpMethod = "POST"
        
        let postBodyString = "goto=news&acct=\(username)&pw=\(password)"
        mutableRequest.addFormHeaders(postBody: postBodyString)
        mutableRequest.addDefaultHeaders()
        
        let (_, response) = try await urlSession.data(for: mutableRequest)
        guard let httpResponse = response as? HTTPURLResponse,
              let cookie = httpResponse.value(forHTTPHeaderField: "Set-Cookie") else {
            throw LoginError.generic
        }
        
        return SaturnKeychainWrapper.shared.store(cookie: cookie,
                                                  username: username)
    }
}

enum LoginError: Error {
    case generic
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
