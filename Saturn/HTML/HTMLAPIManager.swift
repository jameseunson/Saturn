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
    func loadPointsForSubmissions(startFrom: Int?) async throws -> [Int: Int]
    func loadPointsForSubmissions(startFrom: Int?) -> AnyPublisher<[Int: Int], Error>
}

final class HTMLAPIManager: HTMLAPIManaging {
    func loadPointsForSubmissions(startFrom: Int? = nil) async throws -> [Int: Int] {
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
    
    func loadPointsForSubmissions(startFrom: Int? = nil) -> AnyPublisher<[Int: Int], Error> {
        return Future { [weak self] promise in
            guard let self else { return }
            
            Task {
                do {
                    let output = try await self.loadPointsForSubmissions(startFrom: startFrom)
                    promise(.success(output))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func loadAvailableVotesForComments(storyId: Int) async throws -> [Int: HTMLAPICommentVote] {
        guard let url = URL(string: "https://news.ycombinator.com/item?id=\(storyId)") else {
            throw HTMLAPIManagerError.cannotLoad
        }
        let htmlString = try await loadHTML(for: url)
        return try CommentVoteHTMLParser().parseHTML(htmlString)
    }
    
    private func parseVotingLink(element: Element) throws -> (Int, String)? {
        var id: Int?
        var auth: String?
        
        let hrefString = try element.attr("href")
        for component in hrefString.components(separatedBy: "&") {
            let keyValue = component.components(separatedBy: "=")
            guard let key = keyValue.first,
                  let value = keyValue.last else {
                continue
            }
            if key == "id",
               let valueInt = Int(value) {
                id = valueInt
            } else if key == "auth" {
                auth = value
            }
        }
        guard let id,
              let auth else {
            return nil
        }
        return (id, auth)
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
}

enum HTMLAPIManagerError: Error {
    case cannotLoad
    case invalidHTML
    case invalidScore
    case cannotFindElements
}

enum HTMLAPICommentVoteDirection {
    case upvote
    case downvote
}

struct HTMLAPICommentVote {
    let id: Int
    let directions: [HTMLAPICommentVoteDirection]
    let auth: String
}
