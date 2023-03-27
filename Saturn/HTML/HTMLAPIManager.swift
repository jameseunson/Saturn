//
//  HTMLAPIManager.swift
//  Saturn
//
//  Created by James Eunson on 20/3/2023.
//

import Foundation
import Combine
import SwiftSoup

protocol HTMLAPIManaging: AnyObject {
    func loadScoresForLoggedInUserComments(startFrom: Int?) async throws -> [Int: Int]
    func loadScoresForLoggedInUserComments(startFrom: Int?) -> AnyPublisher<[Int: Int], Error>
    func loadAvailableVotesForComments(storyId: Int) async throws -> [Int: HTMLAPIVote]
    func loadAvailableVotesForComments(storyId: Int) -> AnyPublisher<[Int: HTMLAPIVote], Error>
    func loadAvailableVotesForStoriesList(page: Int) async throws -> [Int: HTMLAPIVote]
    func loadAvailableVotesForStoriesList(page: Int) -> AnyPublisher<[Int: HTMLAPIVote], Error>
}

/// The HN API is read-only and does not support authenticated accounts, so when we want to login as a specific user
/// and perform write operations (upvote, etc), the only way to implement this is through HTML scraping using an authenticated cookie
/// Therefore, this class implements various user-authenticated functions using scraping
final class HTMLAPIManager: HTMLAPIManaging {
    
    /// Load score for each user comment, used on the User page
    func loadScoresForLoggedInUserComments(startFrom: Int? = nil) async throws -> [Int: Int] {
        guard let username = SaturnKeychainWrapper.shared.retrieve(for: .username) else { throw HTMLAPIManagerError.cannotLoad }
        
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
    
    func loadScoresForLoggedInUserComments(startFrom: Int? = nil) -> AnyPublisher<[Int: Int], Error> {
        return publisherForAsync {
            try await self.loadScoresForLoggedInUserComments(startFrom: startFrom)
        }
    }
    
    /// Loads whether we can upvote or downvote certain comments in a story thread
    func loadAvailableVotesForComments(storyId: Int) async throws -> [Int: HTMLAPIVote] {
        guard let url = URL(string: "https://news.ycombinator.com/item?id=\(storyId)") else {
            throw HTMLAPIManagerError.cannotLoad
        }
        let htmlString = try await loadHTML(for: url)
        return try VoteHTMLParser().parseCommentHTML(htmlString, storyId: storyId)
    }
    
    func loadAvailableVotesForComments(storyId: Int) -> AnyPublisher<[Int: HTMLAPIVote], Error> {
        return publisherForAsync {
            try await self.loadAvailableVotesForComments(storyId: storyId)
        }
    }
    
    func loadAvailableVotesForStoriesList(page: Int = 0) async throws -> [Int: HTMLAPIVote] {
        guard var urlComponents = URLComponents(string: "https://news.ycombinator.com") else {
            throw HTMLAPIManagerError.cannotLoad
        }
        if page > 0 {
            urlComponents.queryItems = [URLQueryItem(name: "p", value: String(page))]
        }
        guard let url = urlComponents.url else {
            throw HTMLAPIManagerError.cannotLoad
        }
        let htmlString = try await loadHTML(for: url)
        return try VoteHTMLParser().parseStoryListHTML(htmlString)
    }
    
    func loadAvailableVotesForStoriesList(page: Int = 0) -> AnyPublisher<[Int: HTMLAPIVote], Error> {
        return publisherForAsync {
            try await self.loadAvailableVotesForStoriesList(page: page)
        }
    }
    
    /// Perform the actual vote
    /// Example URL: https://news.ycombinator.com/vote?id=34864921&how=up&auth=3bbde44e83c06ae4cae14b4f7b980cacc915ebd4&goto=item%3Fid%3D34858691#34864921
    func vote(direction: HTMLAPIVoteDirection, info: HTMLAPIVote) async throws {
        
        guard var components = URLComponents(string: "https://news.ycombinator.com/vote") else {
            throw HTMLAPIManagerError.cannotVote
        }
        components.queryItems = [URLQueryItem(name: "id", value: String(info.id)),
                                 URLQueryItem(name: "how", value: direction == .upvote ? "up" : "down"),
                                 URLQueryItem(name: "auth", value: info.auth),
                                 URLQueryItem(name: "goto", value: "item%3Fid%3D\(info.storyId)#\(info.id)")]
        guard let url = components.url else {
            throw HTMLAPIManagerError.cannotVote
        }
        
        let htmlString = try await loadHTML(for: url)
        print(htmlString)
    }
    
    // MARK: -
    private func loadHTML(for url: URL) async throws -> String {
        guard let cookie = SaturnKeychainWrapper.shared.retrieve(for: .cookie) else {
            throw HTMLAPIManagerError.cannotLoad
        }
              
        var mutableRequest = URLRequest(url: url)
        mutableRequest.addDefaultHeaders()
        mutableRequest.addValue(cookie, forHTTPHeaderField: "Cookie")
        
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
}

enum HTMLAPIVoteDirection: Codable {
    case upvote
    case downvote
}

struct HTMLAPIVote: Codable, Hashable {
    let id: Int
    let directions: [HTMLAPIVoteDirection]
    let auth: String
    let storyId: Int
    var state: HTMLAPIVoteDirection?
}
