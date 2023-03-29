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
    func parseHTML(_ htmlString: String, for username: String) throws -> [String: Int] {
        let doc: Document = try SwiftSoup.parse(htmlString)
        let elements = try doc.select("tr.athing.comtr")
        
        var map: [String: Int] = [:]
        
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
        
        return map
    }
}
