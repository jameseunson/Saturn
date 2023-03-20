//
//  HTMLAPIManager.swift
//  Saturn
//
//  Created by James Eunson on 20/3/2023.
//

import Foundation
import SwiftSoup

protocol HTMLAPIManaging: AnyObject {
    
}

final class HTMLAPIManager: HTMLAPIManaging {
    func loadPointsForSubmissions(page: Int = 0) async throws -> [Int: Int] {
        guard let cookie = SaturnKeychainWrapper.shared.retrieve(for: .cookie),
              let username = SaturnKeychainWrapper.shared.retrieve(for: .username),
              let url = URL(string: "https://news.ycombinator.com/threads?id=\(username)") else {
            throw HTMLAPIManagerError.cannotLoadSubmissions
        }
        
        var mutableRequest = URLRequest(url: url)
        mutableRequest.addDefaultHeaders()
        mutableRequest.addValue(cookie, forHTTPHeaderField: "Cookie")
        
        let (data, _) = try await URLSession.shared.data(for: mutableRequest)
        guard let htmlString = String(data: data, encoding: .utf8) else {
            throw HTMLAPIManagerError.invalidHTML
        }
        
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
