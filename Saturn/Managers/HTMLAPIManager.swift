//
//  HTMLAPIManager.swift
//  Saturn
//
//  Created by James Eunson on 20/3/2023.
//

import Foundation
import SwiftSoup
import Combine

protocol HTMLAPIManaging: AnyObject {
    func loadPointsForSubmissions(startFrom: Int?) async throws -> [Int: Int]
}

final class HTMLAPIManager: HTMLAPIManaging {
    func loadPointsForSubmissions(startFrom: Int? = nil) async throws -> [Int: Int] {
        print("loadPointsForSubmissions, \(String(describing: startFrom))")
        
        guard let cookie = SaturnKeychainWrapper.shared.retrieve(for: .cookie),
              let username = SaturnKeychainWrapper.shared.retrieve(for: .username) else {
            throw HTMLAPIManagerError.cannotLoadSubmissions
        }
        
        let commentURL: URL?
        if let startFrom {
            commentURL = URL(string: "https://news.ycombinator.com/threads?id=\(username)&next=\(startFrom)")
        } else {
            commentURL = URL(string: "https://news.ycombinator.com/threads?id=\(username)")
        }
        guard let url = commentURL else {
            throw HTMLAPIManagerError.cannotLoadSubmissions
        }
        
        var mutableRequest = URLRequest(url: url)
        mutableRequest.addDefaultHeaders()
        mutableRequest.addValue(cookie, forHTTPHeaderField: "Cookie")
        
        let (data, _) = try await URLSession.shared.data(for: mutableRequest)
        guard let htmlString = String(data: data, encoding: .utf8) else {
            throw HTMLAPIManagerError.invalidHTML
        }
        
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
}

final class CommentScoreHTMLParser {
    func parseHTML(_ htmlString: String, for username: String) throws -> [Int: Int] {
        let doc: Document = try SwiftSoup.parse(htmlString)
        let elements = try doc.select("tr.athing.comtr")
        
        var map: [Int: Int] = [:]
        
        for element in elements {
            guard let elementId = Int(element.id()),
                  let user = try element.select("a.hnuser").first() else {
                throw HTMLAPIManagerError.cannotFindElements
            }
            
            let elementUsername = try user.text()
            if elementUsername != username { /// Ignore all comments not made by logged in user
                continue
            }
            
            guard let score = try element.select("span.score").first() else {
                throw HTMLAPIManagerError.cannotFindElements
            }
            let scoreVal = try score.text()
            
            guard let scoreString = scoreVal.components(separatedBy: CharacterSet.whitespaces).first,
                  let scoreInt = Int(scoreString) else {
                throw HTMLAPIManagerError.invalidScore
            }
            map[elementId] = scoreInt
        }
        
        return map
    }
}

enum HTMLAPIManagerError: Error {
    case cannotLoadSubmissions
    case invalidHTML
    case invalidScore
    case cannotFindElements
}
