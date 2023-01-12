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
        outputString = outputString.replacingOccurrences(of: "<p>", with: "\n\n")
        outputString = outputString.replacingOccurrences(of: "&gt;", with: ">")
        outputString = outputString.replacingOccurrences(of: "&#x27;", with: "'")
        outputString = outputString.replacingOccurrences(of: "&quot;", with: "\"")
        outputString = outputString.replacingOccurrences(of: "&#x2F;", with: "/")
        
        var attrStri = NSMutableAttributedString(string: outputString)
        
        /// Handle italics
        applyFormatting(ss: outputString.substrings(between: "<i>", and: "</i>"),
                        attrStri: &attrStri,
                        attr: [.font: UIFont.preferredFont(forTextStyle: .body).italic])
        attrStri.removeAllOccurrences(of: "<i>")
        attrStri.removeAllOccurrences(of: "</i>")
        
        /// Handle bold
        applyFormatting(ss: outputString.substrings(between: "<b>", and: "</b>"),
                        attrStri: &attrStri,
                        attr: [.font: UIFont.preferredFont(forTextStyle: .body).bold])
        attrStri.removeAllOccurrences(of: "<b>")
        attrStri.removeAllOccurrences(of: "</b>")
        
//        /// Handle quotes
//        applyFormatting(ss: outputString.substrings(between: "> ", and: "\n\n"),
//                        attrStri: &attrStri,
//                        attr: [.foregroundColor: UIColor.gray])
        
        return try AttributedString(attrStri, including: \.uiKit)
    }
    
    static func applyFormatting(ss: [Substring], attrStri: inout NSMutableAttributedString, attr: [NSAttributedString.Key: Any]) {
        for s in ss {
            let range = attrStri.mutableString.range(of: String(s))
            if range.location == NSNotFound {
                continue
            }
            attrStri.addAttributes(attr, range: range)
        }
    }
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
