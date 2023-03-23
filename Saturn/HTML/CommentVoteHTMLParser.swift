//
//  CommentVoteHTMLParser.swift
//  Saturn
//
//  Created by James Eunson on 22/3/2023.
//

import Foundation
import SwiftSoup

/// Extracts which directions each can be voted on (up and/or down),
/// the auth key required to vote on each comment and the id of each comment
final class CommentVoteHTMLParser {
    func parseHTML(_ htmlString: String, storyId: Int) throws -> [Int: HTMLAPICommentVote]  {
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
                map[id] = HTMLAPICommentVote(id: id,
                                             directions: directions,
                                             auth: auth,
                                             storyId: storyId)
            }
        }
        
        return map
    }
    
    private func parseVotingLink(element: Element) throws -> (Int, String)? {
        var id: Int?
        var auth: String?
        
        let hrefString = try element.attr("href")
        guard let url = URL(string: "https://news.ycombinator.com/" + hrefString),
              let components = URLComponents(string: url.absoluteString),
              let queryItems = components.queryItems else {
            return nil
        }
        
        for item in queryItems {
            switch item.name {
            case "id":
                if let itemValue = item.value {
                    id = Int(itemValue)
                }
            case "auth":
                auth = item.value
            default:
                continue
            }
        }
        
        guard let id,
              let auth else {
            return nil
        }
        return (id, auth)
    }
}
