//
//  CommentScoreHTMLParser.swift
//  Saturn
//
//  Created by James Eunson on 22/3/2023.
//

import Foundation
import SwiftSoup

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
