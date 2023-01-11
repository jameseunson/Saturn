//
//  Comment.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 9/1/2023.
//

import Foundation
import Sweep
import UIKit

struct Comment: Identifiable, Hashable, Codable {
    let id: Int
    let by: String
    let kids: [Int]?
    let parent: Int
    let text: AttributedString
    let time: Date
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.by = try container.decode(String.self, forKey: .by)
        self.kids = try container.decodeIfPresent([Int].self, forKey: .kids)
        self.parent = try container.decode(Int.self, forKey: .parent)
        
        let unprocessedText = try container.decode(String.self, forKey: .text)
        if let attributedString = try? Comment.processCommentText(unprocessedText) {
            self.text = attributedString
        } else {
            self.text = AttributedString(unprocessedText)
        }
        
        let timestamp = try container.decode(TimeInterval.self, forKey: .time)
        self.time = Date(timeIntervalSince1970: timestamp)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case by
        case kids
        case parent
        case text
        case time
    }
    
    static func processCommentText(_ input: String) throws -> AttributedString {
        var outputString = input
        outputString = outputString.replacingOccurrences(of: "<p>", with: "\n\n")
        outputString = outputString.replacingOccurrences(of: "&gt;", with: ">")
        outputString = outputString.replacingOccurrences(of: "&#x27;", with: "'")
        outputString = outputString.replacingOccurrences(of: "&quot;", with: "\"")
        outputString = outputString.replacingOccurrences(of: "&#x2F;", with: "/")
        
        let attrStri = NSMutableAttributedString(string: outputString)
        
        /// Handle italics
        let italicSubstrings = outputString.substrings(between: "<i>", and: "</i>")
        if italicSubstrings.count > 0 {
            for s in italicSubstrings {
                let range = attrStri.mutableString.range(of: String(s))
                if range.location == NSNotFound {
                    continue
                }
                attrStri.addAttributes([
                    .font: UIFont.preferredFont(forTextStyle: .body).italic
                ], range: range)
            }
        }
        attrStri.removeAllOccurrences(of: "<i>")
        attrStri.removeAllOccurrences(of: "</i>")
        
        /// Handle quotes
        outputString = attrStri.string
        
        let quoteSubstrings = outputString.substrings(between: "> ", and: "\n\n")
        if quoteSubstrings.count > 0 {
            for s in quoteSubstrings {
                print(s)
            }
        }
        
        return try AttributedString(attrStri, including: \.uiKit)
    }
    
//    static func applyFormatting(mutableString: inout NSMutableAttributedString, start: String, end: String, formatting: [NSAttributedString.Key: Any]) {
//        let string = String(mutableString.string)
//        let ss = string.substrings(between: start, and: end)
//        if ss.count > 0 {
//            for s in ss {
//                let range = mutableString.mutableString.range(of: String(s))
//                if range.location == NSNotFound {
//                    continue
//                }
//                attrStri.addAttributes(formatting, range: range)
//            }
//        }
//        mutableString.removeAllOccurrences(of: start)
//        mutableString.removeAllOccurrences(of: end)
//    }
}

extension NSMutableAttributedString {
    func removeAllOccurrences(of string: String) {
        while(true) {
            let range = self.mutableString.range(of: string)
            if range.location == NSNotFound {
                break
            }
            self.replaceCharacters(in: range, with: "")
        }
    }
}

extension UIFont {
    var bold: UIFont {
        return with(.traitBold)
    }

    var italic: UIFont {
        return with(.traitItalic)
    }

    var boldItalic: UIFont {
        return with([.traitBold, .traitItalic])
    }

    func with(_ traits: UIFontDescriptor.SymbolicTraits...) -> UIFont {
        guard let descriptor = self.fontDescriptor.withSymbolicTraits(UIFontDescriptor.SymbolicTraits(traits).union(self.fontDescriptor.symbolicTraits)) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: 0)
    }

    func without(_ traits: UIFontDescriptor.SymbolicTraits...) -> UIFont {
        guard let descriptor = self.fontDescriptor.withSymbolicTraits(self.fontDescriptor.symbolicTraits.subtracting(UIFontDescriptor.SymbolicTraits(traits))) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: 0)
    }
}
