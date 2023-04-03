//
//  VoteHTMLParser.swift
//  Saturn
//
//  Created by James Eunson on 22/3/2023.
//

import Foundation
import SwiftSoup

/// Extracts which directions each can be voted on (up and/or down),
/// the auth key required to vote on each comment and the id of each comment
final class VoteHTMLParser {
    func parseCommentHTML(_ htmlString: String, storyId: Int) throws -> VoteHTMLParserResponse  {
        return try parse(htmlString, mode: .comments(storyId))
    }
    
    func parseStoryListHTML(_ htmlString: String) throws -> VoteHTMLParserResponse {
        return try parse(htmlString, mode: .storyList)
    }
    
    private func parse(_ htmlString: String, mode: VoteHTMLParserMode) throws -> VoteHTMLParserResponse {
        let doc: Document = try SwiftSoup.parse(htmlString)
        var map = [String: HTMLAPIVote]()

        /// Depending on the mode, we either want to examine all comments (`athing.comtr`) or stories (just plain `athing`)
        let elements: Elements
        switch mode {
        case .comments(_):
            elements = try doc.select("tr.athing.comtr")
        case .storyList:
            elements = try doc.select("tr.athing")
        }
        
        for element in elements {
            if let vote = try extractVote(from: element, mode: mode) {
                map[String(vote.id)] = vote
            }
        }
        
        /// Find whether there's additional pages available for the full comment set
        var hasNextPage = false
        if let _ = try? doc.select("a.morelink").first() {
            hasNextPage = true
        }

        return VoteHTMLParserResponse(scoreMap: map, hasNextPage: hasNextPage)
    }
    
    private func extractVote(from element: Element, mode: VoteHTMLParserMode) throws -> HTMLAPIVote? {
        var directions = [HTMLAPIVoteDirection]()
        var auth: String?
        var id: String?
        var state: HTMLAPIVoteDirection?
        
        /// HTML structure is slightly difference for comments and stories
        /// For stories, the vote state is stored in the next sibling <tr> element
        /// while for comments, everything is contained within the same <tr>
        if mode == .storyList,
            let sibling = try element.nextElementSibling() {
//            let title = try element.select("span[class=titleline] > a").text()
//            print(title)
            state = try extractExistingVoteState(element: sibling)
            
        } else {
            state = try extractExistingVoteState(element: element)
        }
        
        /// Determine whether the user has recently voted, if so,  what direction?
        if let unvote = try element.select("span[id^=unv_] > a").first {
            let unvoteText = try unvote.text()
            if unvoteText == "unvote" {
                state = .upvote
                
            } else if unvoteText == "undown" {
                state = .downvote
            }
        }
        
        /// Extract upvote link, if exists. Hide if the the site instructs us to hide it (`nosee` class)
        if let upvote = try element.select("a.clicky").filter ({ $0.id().contains("up") }).first {
            if let (idResult, authResult) = try parseVotingLink(element: upvote) {
                id = idResult
                auth = authResult
            }
            if state == .upvote ||
                !upvote.hasClass("nosee") {
                directions.append(.upvote)
            }
        }
        
        /// Extract downvote link, if exists. Hide if the the site instructs us to hide it (`nosee` class)
        if let downvote = try element.select("a.clicky").filter ({ $0.id().contains("down") }).first {
            if id == nil || auth == nil {
                if let (idResult, authResult) = try parseVotingLink(element: downvote) {
                    id = idResult
                    auth = authResult
                }
            }
            if state == .downvote ||
                !downvote.hasClass("nosee") {
                directions.append(.downvote)
            }
        }
        
        /// If there is at least one available voting direction, return a vote object for this item
        /// which contains all the information required to place or modify a vote
        if let auth,
           let id,
            let idInt = Int(id) {
            
            let storyId: Int
            switch mode {
            case .comments(let commentsStoryId):
                storyId = commentsStoryId
            case .storyList:
                storyId = idInt
            }
            
            return HTMLAPIVote(id: idInt,
                               directions: directions,
                               auth: auth,
                               storyId: storyId,
                               state: state)
        } else {
            return nil
        }
    }
    
    /// Extract the auth and id strings from the voting link (an element of type `a.clicky`)
    /// Both are required in order to successfully vote, particularly the auth string
    private func parseVotingLink(element: Element) throws -> (String, String)? {
        var id: String?
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
                if let itemValue = item.value,
                   let idInt = Int(itemValue) {
                    id = String(idInt)
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
    
    /// Determine whether the user has recently voted, if so,  what direction?
    private func extractExistingVoteState(element: Element) throws -> HTMLAPIVoteDirection? {
        var state: HTMLAPIVoteDirection?
        if let unvote = try element.select("span[id^=unv_] > a").first {
            let unvoteText = try unvote.text()
            if unvoteText == "unvote" {
                state = .upvote
                
            } else if unvoteText == "undown" {
                state = .downvote
            }
        }
        
        return state
    }
}

enum VoteHTMLParserMode: Equatable {
    case comments(Int)
    case storyList
}

struct VoteHTMLParserResponse: Codable {
    let scoreMap: [String: HTMLAPIVote]
    let hasNextPage: Bool
    
    var dict: [String: Any] {
        ["scoreMap": scoreMap.mapValues { $0.dict },
        "hasNextPage": hasNextPage]
    }
}
