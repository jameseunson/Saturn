//
//  CommentVoteHTMLParser.swift
//  Saturn
//
//  Created by James Eunson on 22/3/2023.
//

import Foundation
import SwiftSoup

final class CommentVoteHTMLParser {
    func parseHTML(_ htmlString: String) throws -> [Int: HTMLAPICommentVote]  {
        let doc: Document = try SwiftSoup.parse(htmlString)
        var map = [Int: HTMLAPICommentVote]()
        
        let elements = try doc.select("tr.athing.comtr")
        for element in elements {
            var directions = [HTMLAPICommentVoteDirection]()
            var auth: String?
            var id: Int?
            
            if let upvote = try element.select("a.clicky").filter ({ $0.id().contains("up") }).first {
                if let (idResult, authResult) = try parseVotingLink(element: upvote) {
                    id = idResult
                    auth = authResult
                }
                directions.append(.upvote)
            }
            if let downvote = try element.select("a.clicky").filter ({ $0.id().contains("down") }).first {
                if id == nil || auth == nil {
                    if let (idResult, authResult) = try parseVotingLink(element: downvote) {
                        id = idResult
                        auth = authResult
                    }
                }
                directions.append(.downvote)
            }
            if let auth,
               let id {
                map[id] = HTMLAPICommentVote(id: id, directions: directions, auth: auth)
            }
        }
        
        return map
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
}
