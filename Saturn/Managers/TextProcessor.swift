//
//  TextProcessor.swift
//  Saturn
//
//  Created by James Eunson on 12/1/2023.
//

import Foundation
import UIKit
import SwiftUI
import SwiftyMarkdown
import RegexBuilder

final class TextProcessor {
    static func processCommentText(_ input: String, forceDetectLinks: Bool = false) throws -> TextProcessorResult {
        var outputString = input

        /// This is faster than using any other html entity decoding (eg interpreting as html using WKWebView, which is very slow)
        /// HN formatting has lots of quirks (for one, it's *not* valid html nor valid markdown) and AttributedString handling of even
        /// valid markdown is somewhat broken, so we can work around it here
        outputString = outputString.replacingOccurrences(of: "<p>* ", with: "\n\n•\t")
        outputString = outputString.replacingOccurrences(of: "<p>- ", with: "\n\n•\t")
        processOrdinalListItems(&outputString)
        
        outputString = outputString.replacingOccurrences(of: "<p>", with: "\n\n ")
        outputString = outputString.replacingOccurrences(of: "&lt;", with: "<")
        outputString = outputString.replacingOccurrences(of: "&gt;", with: ">")
        outputString = outputString.replacingOccurrences(of: "&#x27;", with: "'")
        outputString = outputString.replacingOccurrences(of: "&quot;", with: "\"")
        outputString = outputString.replacingOccurrences(of: "&#x2F;", with: "/")
        outputString = outputString.replacingOccurrences(of: "&amp;", with: "&")
        
        /// Handle italics
        outputString = outputString.replacingOccurrences(of: "<i>", with: "_")
        outputString = outputString.replacingOccurrences(of: "</i>", with: "_")

        /// Handle bold
        outputString = outputString.replacingOccurrences(of: "<b>", with: "**")
        outputString = outputString.replacingOccurrences(of: "</b>", with: "**")
        
        /// NOTE: This is not exhaustive, some less commonly used formatting still breaks
        // TODO: Fix # for code blocks
        
        processLinks(&outputString)
        processCodeBlocks(&outputString)
        processItalicizedQuotes(&outputString)
        processFootnotes(&outputString)
        
        if forceDetectLinks {
            detectLinks(&outputString)
        }
        
        let md = SwiftyMarkdown(string: outputString)
        
        md.link.color = UIColor(Color.accentColor)
        md.blockquotes.color = UIColor(Color.gray)
        md.code.color = UIColor(Color.primary)
        md.code.fontName = UIFont.monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular).fontName
        md.code.fontSize = UIFont.preferredFont(forTextStyle: .callout).pointSize
        
        let s = md.attributedString()
        let rect = s.boundingRect(with: .init(width: UIScreen.main.bounds.size.width - 20, height: CGFloat.infinity), options: [.usesLineFragmentOrigin , .usesFontLeading], context: nil)

        return TextProcessorResult(output: AttributedString(s),
                                   height: rect.size.height)
    }
    
    /// Replace html link with markdown link
    /// Convert <a href="http://google.com">asdf</a> to [asdf](http://google.com)
    private static func processLinks(_ outputString: inout String) {
        let linkRegex = /<a href="(.*?)"(.*?)>(.*?)<\/a>/
        let linkMatches = outputString.matches(of: linkRegex)
        for linkMatch in linkMatches {
            let escapedURL = linkMatch.output.3
                .replacingOccurrences(of: "_", with: "\\_")
                .replacingOccurrences(of: ")", with: "\\)")
                .replacingOccurrences(of: "(", with: "\\(")
            let escapedLabel = linkMatch.output.1
                .replacingOccurrences(of: "_", with: "\\_")
                .replacingOccurrences(of: ")", with: "\\)")
                .replacingOccurrences(of: "(", with: "\\(")
            
            let markdownLink = "[\(escapedURL)](\(escapedLabel))"
            outputString = outputString.replacingOccurrences(of: linkMatch.output.0, with: markdownLink)
        }
    }
    
    /// Convert '<p>3.' to '\n\n3.\t'
    private static func processOrdinalListItems(_ outputString: inout String) {
        let ordinalListItemRegex = /<p>([0-9]+)\.\s+/
        let ordinalListItemMatches = outputString.matches(of: ordinalListItemRegex)
        for ordinalListItemMatch in ordinalListItemMatches {
            let ordinalListItemString = "\n\n\(ordinalListItemMatch.output.1)\t"
            outputString = outputString.replacingOccurrences(of: ordinalListItemMatch.output.0, with: ordinalListItemString)
        }
    }
    
    /// Converts <pre><code> formatted code blocks to tab indented, which makes
    /// them function correctly as code blocks within the markdown library
    private static func processCodeBlocks(_ outputString: inout String) {
        guard outputString.contains("<pre><code>") else { return }
        
        let characterRules = [CharacterRule(primaryTag: CharacterRuleTag(tag: "<pre><code>", type: .open), otherTags: [CharacterRuleTag(tag: "</code></pre>", type: .close)], styles: [1: CharacterStyle.code])]
        let processor = SwiftyTokeniser( with : characterRules )
        let tokens = processor.process(outputString)

        for token in tokens {
            if let style = token.characterStyles.first as? CharacterStyle,
               style == .code {
                var outputLines = [String]()
                for line in token.outputString.components(separatedBy: CharacterSet.newlines) {
                    outputLines.append(String("\t" + line))
                }
                let codeOutputString = outputLines.joined(separator: "\n")
                outputString = outputString.replacing(token.outputString, with: codeOutputString)
            }
        }
        
        /// Handle code blocks
        outputString = outputString.replacingOccurrences(of: "<pre><code>", with: "")
        outputString = outputString.replacingOccurrences(of: "</code></pre>", with: "")
    }
    
    /// Italicized quotes look broken and don't turn to grey correctly within the markdown library,
    /// so strip the italicization and leave them as only quotes
    private static func processItalicizedQuotes(_ outputString: inout String) {
        let italicizedQuoteRegex = /_>(.*?)_\n/
        let italicizedQuoteRegexMatches = outputString.matches(of: italicizedQuoteRegex)
        for italicizedQuoteRegexMatch in italicizedQuoteRegexMatches {
            let matchString = italicizedQuoteRegexMatch.output.0
            outputString = outputString.replacingOccurrences(of: matchString, with: matchString.replacingOccurrences(of: "_", with: ""))
        }
    }
    
    private static func processFootnotes(_ outputString: inout String) {
        let footnoteRegex = /(\[[0-9]+\]):/
        let footnoteMatches = outputString.matches(of: footnoteRegex)
        for footnoteMatch in footnoteMatches {
            let footnoteStringWithoutColon = "\(footnoteMatch.output.1)"
            outputString = outputString.replacingOccurrences(of: footnoteMatch.output.0, with: footnoteStringWithoutColon)
        }
    }
    
    private static func detectLinks(_ outputString: inout String) {
        let linkRegex = /(?m)((?:(?:https?|ftp|file):\/\/|www\.|ftp\.)(?:\([-A-Z0-9+&@#\/%=~_|$?!:,.]*\)|[-A-Z0-9+&@#\/%=~_|$?!:,.])*(?:\([-A-Z0-9+&@#\/%=~_|$?!:,.]*\)|[A-Z0-9+&@#\/%=~_|$]))/.ignoresCase()

        let linkMatches = outputString.matches(of: linkRegex)
        linkMatches.forEach { linkMatch in
            /// Assume https
            var linkMatchString = linkMatch.output.0
            if linkMatchString.starts(with: /www/) {
                linkMatchString = "https://" + linkMatchString
            }
            let markdownLink = "[\(linkMatchString)](\(linkMatchString))"
            outputString = outputString.replacingOccurrences(of: linkMatch.output.0, with: markdownLink)
        }
        
        let emailRegex = /[A-Z0-9a-z]+([._%+-]{1}[A-Z0-9a-z]+)*@[A-Z0-9a-z]+([.-]{1}[A-Z0-9a-z]+)*(\\.[A-Za-z]{2,4}){0,1}/
        let emailMatches = outputString.matches(of: emailRegex)
        for emailMatch in emailMatches {
            let markdownLink = "[\(emailMatch.output.0)](\(emailMatch.output.0))"
            outputString = outputString.replacingOccurrences(of: emailMatch.output.0, with: markdownLink)
        }
    }
}

struct TextProcessorResult {
    let output: AttributedString
    let height: CGFloat
}
