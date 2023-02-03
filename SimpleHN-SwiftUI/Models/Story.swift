//
//  Story.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 9/1/2023.
//

import Foundation
import UIKit
import Combine

struct Story: Codable, Identifiable, Hashable {
    let id: Int
    let score: Int
    let time: Date
    let descendants: Int?
    let by: String
    let title: String
    let kids: [Int]?
    let type: String
    let url: URL?
    let text: AttributedString?
    
    init(id: Int, score: Int, time: Date, descendants: Int?, by: String, title: String, kids: [Int]?, type: String, url: URL?, text: AttributedString?) {
        self.id = id
        self.score = score
        self.time = time
        self.descendants = descendants
        self.by = by
        self.title = title
        self.kids = kids
        self.type = type
        self.url = url
        self.text = text
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.score = try container.decode(Int.self, forKey: .score)
        
        let timestamp = try container.decode(TimeInterval.self, forKey: .time)
        self.time = Date(timeIntervalSince1970: timestamp)
        
        self.descendants = try container.decodeIfPresent(Int.self, forKey: .descendants)
        self.by = try container.decode(String.self, forKey: .by)
        self.title = try container.decode(String.self, forKey: .title)
        self.kids = try container.decodeIfPresent([Int].self, forKey: .kids)
        self.type = try container.decode(String.self, forKey: .type)
        self.url = try container.decodeIfPresent(URL.self, forKey: .url)
        
        if let unprocessedText = try container.decodeIfPresent(String.self, forKey: .text) {
            if let result = try? TextProcessor.processCommentText(unprocessedText) {
                self.text = result.output
            } else {
                self.text = AttributedString(unprocessedText)
            }
        } else {
            self.text = nil
        }
    }
    
    func hasComments() -> Bool {
        kids?.count ?? 0 > 0
    }
    
    // MARK: -
    func urlForFavicon() -> URL? {
        guard let url = url,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme else {
            return nil
        }
        
        components.path = "/favicon.ico"
        guard let iconUrl = components.url,
              scheme == "https" else {
            return nil
        }
        return iconUrl
    }
    
    enum CodingKeys: CodingKey {
        case id
        case score
        case time
        case descendants
        case by
        case title
        case kids
        case type
        case url
        case text
    }
}

extension Story {
    static func fakeStory() -> Story {
        Story.init(id: 1234, score: 100, time: Date(), descendants: nil, by: "fakeperson", title: "A fake story with a convincing headline", kids: [1234], type: "story", url: nil, text: nil)
    }
    
    static func fakeStoryWithNoComments() -> Story {
        Story.init(id: 1234, score: 100, time: Date(), descendants: nil, by: "fakeperson", title: "A fake story with a convincing headline", kids: [], type: "story", url: nil, text: nil)
    }
}
