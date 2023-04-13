//
//  CommentScoreHTMLParser.swift
//  Saturn
//
//  Created by James Eunson on 22/3/2023.
//

import Foundation
import SwiftSoup

/// Extracts the number of upvotes (score) of each comment
/// This information is only available to the current user about their own comments,
/// so we do not attempt to extract scores for comments by other users
final class CommentScoreHTMLParser {
    func parseHTML(_ htmlString: String, for username: String) throws -> CommentScoreHTMLParserResponse {
        let doc: Document = try SwiftSoup.parse(htmlString)
        let elements = try doc.select("tr.athing.comtr")
        
        var map: ScoreMap = [:]
        
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
            map[String(elementId)] = scoreInt
        }
        
        if let moreLink = try? doc.select("a.morelink").first(),
           let id = extractNextPageItemId(element: moreLink) {
            return CommentScoreHTMLParserResponse(scoreMap: map, nextPageItemId: id)
            
        } else {
            return CommentScoreHTMLParserResponse(scoreMap: map, nextPageItemId: nil)
        }
    }
    
    func extractNextPageItemId(element: Element) -> Int? {
        guard let hrefString = try? element.attr("href") else {
            return nil
        }
        guard let url = URL(string: "https://news.ycombinator.com/" + hrefString),
              let components = URLComponents(string: url.absoluteString),
              let queryItems = components.queryItems else {
            return nil
        }
        var id: Int?
        for item in queryItems {
            if item.name == "next",
               let value = item.value,
               let valueInt = Int(value) {
                id = valueInt
            }
        }
        return id
    }
}

struct CommentScoreHTMLParserResponse: Codable {
    let scoreMap: ScoreMap
    let nextPageItemId: Int?
    
    var dict: [String: Any] {
        var dict: [String: Any] = ["scoreMap": scoreMap]
        if let nextPageItemId {
            dict["nextPageItemId"] = nextPageItemId
        }
        return dict
    }
}
