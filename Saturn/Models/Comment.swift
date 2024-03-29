//
//  Comment.swift
//  Saturn
//
//  Created by James Eunson on 9/1/2023.
//

import Foundation
import UIKit
import Combine

final class Comment: Identifiable, Hashable, Codable {
    static func == (lhs: Comment, rhs: Comment) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    let id: Int
    let by: String
    let kids: [Int]?
    let parent: Int
    let text: String
    let time: Date
    
    var score: Int?
    var processedText: AttributedString?
    var processedTextHeight: CGFloat = 0
    
    var url: URL? {
        return URL(string: "https://news.ycombinator.com/item?id=\(id)")
    }

    init(id: Int, by: String, kids: [Int]?, parent: Int, text: String, time: Date, score: Int? = nil) {
        self.id = id
        self.by = by
        self.kids = kids
        self.parent = parent
        self.text = text
        self.time = time
        self.score = score
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.by = try container.decode(String.self, forKey: .by)
        self.kids = try container.decodeIfPresent([Int].self, forKey: .kids)
        self.parent = try container.decode(Int.self, forKey: .parent)
        self.text = try container.decode(String.self, forKey: .text)
        
        let timestamp = try container.decode(TimeInterval.self, forKey: .time)
        self.time = Date(timeIntervalSince1970: timestamp)
    }

    func loadMarkdown() -> AnyPublisher<Comment, Error> {
        AsyncTools.publisherForAsync {
            await self.processText()
        }
    }
    
    @discardableResult
    func loadMarkdown() async -> Comment {
        await processText()
    }
    
    private func processText() async -> Comment {
        return await withCheckedContinuation { [weak self] continuation in
            guard let self else { return }
            if let result = try? TextProcessor.processCommentText(self.text) {
                self.processedText = result.output
                self.processedTextHeight = result.height
            } else {
                self.processedText = AttributedString(self.text)
                // TODO: Height for failure case
            }
            continuation.resume(with: .success((self)))
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case by
        case kids
        case parent
        case text
        case time
    }
}

extension Comment {
    static func fakeComment() -> Comment {
        return Comment(id: 1234, by: "person", kids: nil, parent: 1234, text: "asdf", time: Date())
    }
    
    static func fakeCommentWithScore() -> Comment {
        return Comment(id: 1234, by: "person", kids: nil, parent: 1234, text: "asdf", time: Date(), score: 10)
    }
}

enum CommentExpandedState: Equatable {
    case expanded
    case collapsed
    case hidden
}
