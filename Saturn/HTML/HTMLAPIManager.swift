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

typealias ScoreMap = [String: Int]

/// @mockable
protocol HTMLAPIManaging: AnyObject {
    func loadScoresForLoggedInUserComments(startFrom: Int?, cacheBehavior: CacheBehavior) async throws -> APIResponse<CommentScoreHTMLParserResponse>
    func loadScoresForLoggedInUserComments(startFrom: Int?, cacheBehavior: CacheBehavior) -> AnyPublisher<APIResponse<CommentScoreHTMLParserResponse>, Error>
    func loadAvailableVotesForComments(page: Int, storyId: Int, cacheBehavior: CacheBehavior) async throws -> APIResponse<VoteHTMLParserResponse>
    func loadAvailableVotesForComments(page: Int, storyId: Int, cacheBehavior: CacheBehavior) -> AnyPublisher<APIResponse<VoteHTMLParserResponse>, Error>
    func loadAvailableVotesForStoriesList(type: StoryListType, page: Int, cacheBehavior: CacheBehavior) async throws -> APIResponse<VoteHTMLParserResponse>
    func loadAvailableVotesForStoriesList(type: StoryListType, page: Int, cacheBehavior: CacheBehavior) -> AnyPublisher<APIResponse<VoteHTMLParserResponse>, Error>
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
    func loadScoresForLoggedInUserComments(startFrom: Int? = nil, cacheBehavior: CacheBehavior = .default) async throws -> APIResponse<CommentScoreHTMLParserResponse> {
        guard let username = keychainWrapper.retrieve(for: .username) else { throw HTMLAPIManagerError.cannotLoad }
        
        let commentURL: URL?
        if let startFrom {
            commentURL = URL(string: "https://news.ycombinator.com/threads?id=\(username)&next=\(startFrom)")
        } else {
            commentURL = URL(string: "https://news.ycombinator.com/threads?id=\(username)")
        }
        
        guard let url = commentURL else { throw HTMLAPIManagerError.cannotLoad }
        let cacheKey = url.cacheKey
        
        if let response = cache.get(for: cacheKey),
           response.isValid(cacheBehavior: cacheBehavior),
           case let .json(data) = response.value {
            return APIResponse(response: try decoder.decodeResponse(data), source: .cache)
            
        } else {
            let htmlString = try await loadHTML(for: url)
            let scoreMap = try CommentScoreHTMLParser().parseHTML(htmlString, for: username)
            
            cache.set(value: .json(scoreMap.dict), for: cacheKey)
            
            return APIResponse(response: scoreMap, source: .network)
        }
    }
    
    func loadScoresForLoggedInUserComments(startFrom: Int? = nil, cacheBehavior: CacheBehavior = .default) -> AnyPublisher<APIResponse<CommentScoreHTMLParserResponse>, Error> {
        return AsyncTools.publisherForAsync {
            try await self.loadScoresForLoggedInUserComments(startFrom: startFrom)
        }
    }
    
    /// Loads whether we can upvote or downvote certain comments in a story thread
    func loadAvailableVotesForComments(page: Int = 1, storyId: Int, cacheBehavior: CacheBehavior = .default) async throws -> APIResponse<VoteHTMLParserResponse> {
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
        let cacheKey = url.cacheKey
        if let response = cache.get(for: cacheKey),
           response.isValid(cacheBehavior: cacheBehavior),
           case let .json(data) = response.value {
            return APIResponse(response: try decoder.decodeResponse(data), source: .cache)
            
        } else {
            
            let htmlString = try await loadHTML(for: url)
            let result = try VoteHTMLParser().parseCommentHTML(htmlString, storyId: storyId)
            
            cache.set(value: .json(result.dict), for: cacheKey)
            
            return APIResponse(response: result, source: .network)
        }
    }
    
    func loadAvailableVotesForComments(page: Int = 1, storyId: Int, cacheBehavior: CacheBehavior = .default) -> AnyPublisher<APIResponse<VoteHTMLParserResponse>, Error> {
        return AsyncTools.publisherForAsync {
            try await self.loadAvailableVotesForComments(page: page, storyId: storyId)
        }
    }
    
    func loadAvailableVotesForStoriesList(type: StoryListType, page: Int = 0, cacheBehavior: CacheBehavior = .default) async throws -> APIResponse<VoteHTMLParserResponse> {
        guard var urlComponents = URLComponents(string: "https://news.ycombinator.com/\(type.httpPath)") else {
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
    
    func loadAvailableVotesForStoriesList(type: StoryListType, page: Int = 0, cacheBehavior: CacheBehavior = .default) -> AnyPublisher<APIResponse<VoteHTMLParserResponse>, Error> {
        return AsyncTools.publisherForAsync {
            try await self.loadAvailableVotesForStoriesList(type: type, page: page)
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
                                     username: username,
                                     password: password)
    }
    
    // MARK: -
    private func loadHTML(for url: URL) async throws -> String {
        let request = try createAuthenticatedRequest(for: url)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let htmlString = String(data: data, encoding: .utf8) else {
            throw HTMLAPIManagerError.invalidHTML
        }
        
        /// Check if user has been logged out
        if !checkIfAuthenticated(htmlString) {
            print("User session is invalid, user is LOGGED OUT, restarting session")
            guard let username = keychainWrapper.retrieve(for: .username),
                  let password = keychainWrapper.retrieve(for: .password),
                  try await login(with: username, password: password) else {
                throw HTMLAPIManagerError.cannotLoad
            }
            
            /// Recreate request with updated cookie
            let updatedRequest = try createAuthenticatedRequest(for: url)
            
            let (data, _) = try await URLSession.shared.data(for: updatedRequest)
            guard let updatedHtmlString = String(data: data, encoding: .utf8) else {
                throw HTMLAPIManagerError.invalidHTML
            }
            /// Check if second attempt after login was successful, if not, log user out and throw exception
            if !checkIfAuthenticated(updatedHtmlString) {
                keychainWrapper.clearCredential()
                throw HTMLAPIManagerError.userLoggedOut
            }
            return updatedHtmlString
            
        } else {
            return htmlString
        }
    }
    
    private func createAuthenticatedRequest(for url: URL) throws -> URLRequest {
        /// Recreate request with updated cookie
        guard let cookie = keychainWrapper.retrieve(for: .cookie) else {
            throw HTMLAPIManagerError.cannotLoad
        }
              
        var mutableRequest = URLRequest(url: url)
        mutableRequest.addDefaultHeaders()
        mutableRequest.addValue(cookie, forHTTPHeaderField: "Cookie")
        print("loadHTML: \(url)")
        
        return mutableRequest
    }
    
    /// Search for the login link, which indicates the session has expired
    private func checkIfAuthenticated(_ htmlString: String) -> Bool {
        do {
            return try LoginLinkHTMLParser().checkUserAuthenticated(htmlString)
        } catch {
            return false
        }
    }
}

enum HTMLAPIManagerError: LocalizedError {
    case cannotLoad
    case invalidHTML
    case invalidScore
    case cannotFindElements
    case cannotVote
    case cannotFlag
    case cannotLogin
    case userLoggedOut
    
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
        case .userLoggedOut:
            return NSLocalizedString(
                "You have been logged out of your account. Please login again to use authenticated features.",
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
    func loadAvailableVotesForComments(page: Int = 1, storyId: Int, cacheBehavior: CacheBehavior = .default) async throws -> APIResponse<VoteHTMLParserResponse> {
        try await loadAvailableVotesForComments(page: page, storyId: storyId, cacheBehavior: cacheBehavior)
    }
    func loadAvailableVotesForComments(page: Int = 1, storyId: Int, cacheBehavior: CacheBehavior = .default) -> AnyPublisher<APIResponse<VoteHTMLParserResponse>, Error> {
        loadAvailableVotesForComments(page: page, storyId: storyId, cacheBehavior: cacheBehavior)
    }
    func loadScoresForLoggedInUserComments(startFrom: Int? = nil, cacheBehavior: CacheBehavior = .default) async throws -> APIResponse<CommentScoreHTMLParserResponse> {
        try await loadScoresForLoggedInUserComments(startFrom: startFrom, cacheBehavior: cacheBehavior)
    }
    func loadScoresForLoggedInUserComments(startFrom: Int? = nil, cacheBehavior: CacheBehavior = .default) -> AnyPublisher<APIResponse<CommentScoreHTMLParserResponse>, Error> {
        loadScoresForLoggedInUserComments(startFrom: startFrom, cacheBehavior: cacheBehavior)
    }
    func loadAvailableVotesForStoriesList(type: StoryListType, page: Int = 0, cacheBehavior: CacheBehavior = .default) async throws -> APIResponse<VoteHTMLParserResponse> {
        try await loadAvailableVotesForStoriesList(type: type, page: page, cacheBehavior: cacheBehavior)
    }
    func loadAvailableVotesForStoriesList(type: StoryListType, page: Int = 0, cacheBehavior: CacheBehavior = .default) -> AnyPublisher<APIResponse<VoteHTMLParserResponse>, Error> {
        loadAvailableVotesForStoriesList(type: type, page: page, cacheBehavior: cacheBehavior)
    }
}
