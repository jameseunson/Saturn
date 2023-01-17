//
//  CommentTextProcessor.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 12/1/2023.
//

import Foundation
import UIKit

final class CommentTextProcessor {
    static func processCommentText(_ input: String) throws -> AttributedString {
        var outputString = input
        
        /// This is faster than using any other html entity decoding (eg interpreting as html using WKWebView, which is very slow)
        outputString = outputString.replacingOccurrences(of: "<p>", with: "\n\n")
        outputString = outputString.replacingOccurrences(of: "&gt;", with: ">")
        outputString = outputString.replacingOccurrences(of: "&#x27;", with: "'")
        outputString = outputString.replacingOccurrences(of: "&quot;", with: "\"")
        outputString = outputString.replacingOccurrences(of: "&#x2F;", with: "/")
        
        /// Handle italics
        outputString = outputString.replacingOccurrences(of: "<i>", with: "_")
        outputString = outputString.replacingOccurrences(of: "</i>", with: "_")

        /// Handle bold
        outputString = outputString.replacingOccurrences(of: "<b>", with: "**")
        outputString = outputString.replacingOccurrences(of: "</b>", with: "**")
        
        /// Handle code blocks
        outputString = outputString.replacingOccurrences(of: "<pre><code>", with: "```\n")
        outputString = outputString.replacingOccurrences(of: "</code></pre>", with: "\n```\n")
        
        /// NOTE: This is not exhaustive, some less commonly used formatting still breaks
        // TODO: Fix # for code blocks
        
        /// Replace html link with markdown link
        processLinks(&outputString)
        
        return try parseMarkdown(outputString)
    }
    
    static func processLinks(_ outputString: inout String) {
        let linkRegex = /<a href="(.*?)"(.*?)>(.*?)<\/a>/
        let linkMatches = outputString.matches(of: linkRegex)
        for linkMatch in linkMatches {
            let markdownLink = "[\(linkMatch.output.3)](\(linkMatch.output.1))"
            outputString = outputString.replacingOccurrences(of: linkMatch.output.0, with: markdownLink)
        }
    }
    
    static func parseMarkdown(_ outputString: String) throws -> AttributedString {
        guard let markdownData = outputString.data(using: .utf8) else {
            throw APIManagerError.generic
        }
        
        /// Inspired by https://github.com/frankrausch/AttributedStringStyledMarkdown
        /// Adds grey styling to block quotes and adds proper line breaks, which AttributedString strips for no apparent reason
        var s = try AttributedString(markdown: markdownData, options: .init(allowsExtendedAttributes: true, interpretedSyntax: .full, failurePolicy: .returnPartiallyParsedIfPossible, languageCode: "en"))
        for (intentBlock, intentRange) in s.runs[AttributeScopes.FoundationAttributes.PresentationIntentAttribute.self].reversed() {
            guard let intentBlock else {
                continue
            }
            for intent in intentBlock.components {
                if intent.kind == .blockQuote {
                    s[intentRange].foregroundColor = .secondaryLabel
                }
                if intentRange.lowerBound != s.startIndex {
                    s.characters.insert(contentsOf: "\n\n", at: intentRange.lowerBound)
                }
            }
        }
        
        return s
    }
}
