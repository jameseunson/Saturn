//
//  HTMLAPIManager.swift
//  Saturn
//
//  Created by James Eunson on 20/3/2023.
//

import Foundation
import Combine
import SwiftSoup
import Factory

/// @mockable
protocol HTMLAPIManaging: AnyObject {
    func loadScoresForLoggedInUserComments(startFrom: Int?) async throws -> [String: Int]
    func loadScoresForLoggedInUserComments(startFrom: Int?) -> AnyPublisher<[String: Int], Error>
    func loadAvailableVotesForComments(page: Int, storyId: Int) async throws -> APIResponse<VoteHTMLParserResponse>
    func loadAvailableVotesForComments(page: Int, storyId: Int) -> AnyPublisher<APIResponse<VoteHTMLParserResponse>, Error>
    func loadAvailableVotesForStoriesList(page: Int, cacheBehavior: CacheBehavior) async throws -> APIResponse<VoteHTMLParserResponse>
    func loadAvailableVotesForStoriesList(page: Int, cacheBehavior: CacheBehavior) -> AnyPublisher<APIResponse<VoteHTMLParserResponse>, Error>
    func vote(direction: HTMLAPIVoteDirection, info: HTMLAPIVote) async throws
    func unvote(info: HTMLAPIVote) async throws
    func flag(info: HTMLAPIVote) async throws
    func login(with username: String, password: String) async throws -> Bool
}

/// The HN API is read-only and does not support authenticated accounts, so when we want to login as a specific user
/// and perform write operations (upvote, etc), the only way to implement this is through HTML scraping using an authenticated cookie
/// Therefore, this class implements various user-authenticated functions using scraping
final class HTMLAPIManager: HTMLAPIManaging {
    @Injected(\.apiMemoryResponseCache) private var cache
    @Injected(\.apiDecoder) private var decoder
    @Injected(\.keychainWrapper) private var keychainWrapper
    
    lazy var loginUrlSession = URLSession(configuration: .default, delegate: loginDelegate, delegateQueue: nil)
    let loginDelegate = LoginAuthenticationURLSessionDelegate()
    
    init() {}
    
    /// Load score for each user comment, used on the User page
    func loadScoresForLoggedInUserComments(startFrom: Int? = nil) async throws -> [String: Int] {
        guard let username = keychainWrapper.retrieve(for: .username) else { throw HTMLAPIManagerError.cannotLoad }
        
        let commentURL: URL?
        if let startFrom {
            commentURL = URL(string: "https://news.ycombinator.com/threads?id=\(username)&next=\(startFrom)")
        } else {
            commentURL = URL(string: "https://news.ycombinator.com/threads?id=\(username)")
        }
        
        guard let url = commentURL else { throw HTMLAPIManagerError.cannotLoad }
        let htmlString = try await loadHTML(for: url)
        
        return try CommentScoreHTMLParser().parseHTML(htmlString, for: username)
    }
    
    func loadScoresForLoggedInUserComments(startFrom: Int? = nil) -> AnyPublisher<[String: Int], Error> {
        return publisherForAsync {
            try await self.loadScoresForLoggedInUserComments(startFrom: startFrom)
        }
    }
    
    /// Loads whether we can upvote or downvote certain comments in a story thread
    func loadAvailableVotesForComments(page: Int = 1, storyId: Int) async throws -> APIResponse<VoteHTMLParserResponse> {
        guard var urlComponents = URLComponents(string: "https://news.ycombinator.com/item") else {
            throw HTMLAPIManagerError.cannotLoad
        }
        if page > 1 {
            urlComponents.queryItems = [URLQueryItem(name: "p", value: String(page)), URLQueryItem(name: "id", value: String(storyId))]
        } else {
            urlComponents.queryItems = [URLQueryItem(name: "id", value: String(storyId))]
        }
        guard let url = urlComponents.url else {
            throw HTMLAPIManagerError.cannotLoad
        }
        
        let htmlString = try await loadHTML(for: url)
        let result = try VoteHTMLParser().parseCommentHTML(htmlString, storyId: storyId)
        
        return APIResponse(response: result, source: .network)
    }
    
    func loadAvailableVotesForComments(page: Int = 1, storyId: Int) -> AnyPublisher<APIResponse<VoteHTMLParserResponse>, Error> {
        return publisherForAsync {
            try await self.loadAvailableVotesForComments(page: page, storyId: storyId)
        }
    }
    
    func loadAvailableVotesForStoriesList(page: Int = 0, cacheBehavior: CacheBehavior = .default) async throws -> APIResponse<VoteHTMLParserResponse> {
        guard var urlComponents = URLComponents(string: "https://news.ycombinator.com") else {
            throw HTMLAPIManagerError.cannotLoad
        }
        if page > 0 {
            urlComponents.queryItems = [URLQueryItem(name: "p", value: String(page))]
        }
        guard let url = urlComponents.url else {
            throw HTMLAPIManagerError.cannotLoad
        }
        let cacheKey = url.cacheKey
        
        let voteResponse: VoteHTMLParserResponse
        if let response = cache.get(for: cacheKey),
           response.isValid(cacheBehavior: cacheBehavior),
           case let .json(data) = response.value {
            return APIResponse(response: try decoder.decodeResponse(data), source: .cache)
            
        } else {
            let htmlString = try await loadHTML(for: url)
            voteResponse = try VoteHTMLParser().parseStoryListHTML(htmlString)
            
            cache.set(value: .json(voteResponse.dict),
                                               for: cacheKey)
        }
        
        return APIResponse(response: voteResponse, source: .network)
    }
    
    func loadAvailableVotesForStoriesList(page: Int = 0, cacheBehavior: CacheBehavior = .default) -> AnyPublisher<APIResponse<VoteHTMLParserResponse>, Error> {
        return publisherForAsync {
            try await self.loadAvailableVotesForStoriesList(page: page)
        }
    }
    
    /// Perform the actual vote
    /// Example URL: https://news.ycombinator.com/vote?id=34864921&how=up&auth=3bbde44e83c06ae4cae14b4f7b980cacc915ebd4&goto=item%3Fid%3D34858691#34864921
    func vote(direction: HTMLAPIVoteDirection, info: HTMLAPIVote) async throws {
        guard var components = URLComponents(string: "https://news.ycombinator.com/vote"),
              let url = components.applyQueryParameters(for: info, direction: direction).url else {
            throw HTMLAPIManagerError.cannotVote
        }
        
        let htmlString = try await loadHTML(for: url)
        if htmlString != "Unknown." {
            throw HTMLAPIManagerError.cannotVote
        }
    }
    
    func unvote(info: HTMLAPIVote) async throws {
        try await vote(direction: .unvote, info: info)
    }
    
    func flag(info: HTMLAPIVote) async throws {
        guard var components = URLComponents(string: "https://news.ycombinator.com/flag"),
              let url = components.applyQueryParameters(for: info).url else {
            throw HTMLAPIManagerError.cannotFlag
        }
        
        let htmlString = try await loadHTML(for: url)
        print(htmlString)
        
        // TODO: Error handling
    }
    
    func login(with username: String, password: String) async throws -> Bool {
        guard let url = URL(string: "https://news.ycombinator.com/login"),
              !username.isEmpty,
              !password.isEmpty else {
            throw HTMLAPIManagerError.cannotLogin
        }
        
        var mutableRequest = URLRequest(url: url)
        mutableRequest.httpMethod = "POST"
        
        let postBodyString = "goto=news&acct=\(username)&pw=\(password)"
        mutableRequest.addFormHeaders(postBody: postBodyString)
        mutableRequest.addDefaultHeaders()
        
        let (_, response) = try await loginUrlSession.data(for: mutableRequest)
        guard let httpResponse = response as? HTTPURLResponse,
              let cookie = httpResponse.value(forHTTPHeaderField: "Set-Cookie") else {
            throw HTMLAPIManagerError.cannotLogin
        }
        
        return keychainWrapper.store(cookie: cookie,
                                     username: username)
    }
    
    // MARK: -
    private func loadHTML(for url: URL) async throws -> String {
        guard let cookie = keychainWrapper.retrieve(for: .cookie) else {
            throw HTMLAPIManagerError.cannotLoad
        }
              
        var mutableRequest = URLRequest(url: url)
        mutableRequest.addDefaultHeaders()
        mutableRequest.addValue(cookie, forHTTPHeaderField: "Cookie")
        print("loadHTML: \(url)")
        
        let (data, _) = try await URLSession.shared.data(for: mutableRequest)
        guard let htmlString = String(data: data, encoding: .utf8) else {
            throw HTMLAPIManagerError.invalidHTML
        }
        return htmlString
    }
    
    private func publisherForAsync<T>(action: @escaping () async throws -> T) -> AnyPublisher<T, Error> {
        return Future { promise in
            Task {
                do {
                    let output = try await action()
                    promise(.success(output))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

enum HTMLAPIManagerError: Error {
    case cannotLoad
    case invalidHTML
    case invalidScore
    case cannotFindElements
    case cannotVote
    case cannotFlag
    case cannotLogin
    
    var errorDescription: String? {
        switch self {
        case .cannotLoad, .invalidHTML, .invalidScore, .cannotFindElements:
            return NSLocalizedString(
                "Could not load vote information for this story.",
                comment: ""
            )
        case .cannotVote:
            return NSLocalizedString(
                "An error was encountered when voting on this item.",
                comment: ""
            )
        case .cannotFlag:
            return NSLocalizedString(
                "An error was encountered when flagging this item.",
                comment: ""
            )
        case .cannotLogin:
            return NSLocalizedString(
                "Could not login with the credentials provided.",
                comment: ""
            )
        }
    }
}

extension URLComponents {
    mutating func applyQueryParameters(for info: HTMLAPIVote, direction: HTMLAPIVoteDirection? = nil) -> URLComponents {
        self.queryItems = [URLQueryItem(name: "id", value: String(info.id)),
                           URLQueryItem(name: "auth", value: info.auth),
                           URLQueryItem(name: "goto", value: "item%3Fid%3D\(info.storyId)#\(info.id)")]
        if let direction {
            self.queryItems?.append(URLQueryItem(name: "how", value: direction.rawValue))
        }
        return self
    }
}

/// Add `page` and `cacheBehavior` defaults to `HTMLAPIManaging` protocol
extension HTMLAPIManaging {
    func loadAvailableVotesForComments(page: Int = 1, storyId: Int) async throws -> APIResponse<VoteHTMLParserResponse> {
        try await loadAvailableVotesForComments(page: page, storyId: storyId)
    }
    func loadAvailableVotesForComments(page: Int = 1, storyId: Int) -> AnyPublisher<APIResponse<VoteHTMLParserResponse>, Error> {
        loadAvailableVotesForComments(page: page, storyId: storyId)
    }
    func loadScoresForLoggedInUserComments(startFrom: Int? = nil) async throws -> [String: Int] {
        try await loadScoresForLoggedInUserComments(startFrom: startFrom)
    }
    func loadScoresForLoggedInUserComments(startFrom: Int? = nil) -> AnyPublisher<[String: Int], Error> {
        loadScoresForLoggedInUserComments(startFrom: startFrom)
    }
    func loadAvailableVotesForStoriesList(page: Int = 0, cacheBehavior: CacheBehavior = .default) async throws -> APIResponse<VoteHTMLParserResponse> {
        try await loadAvailableVotesForStoriesList(page: page, cacheBehavior: cacheBehavior)
    }
    func loadAvailableVotesForStoriesList(page: Int = 0, cacheBehavior: CacheBehavior = .default) -> AnyPublisher<APIResponse<VoteHTMLParserResponse>, Error> {
        loadAvailableVotesForStoriesList(page: page, cacheBehavior: cacheBehavior)
    }
}
