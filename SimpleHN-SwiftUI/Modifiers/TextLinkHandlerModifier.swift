//
//  CommentLinkHandlerModifier.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 25/1/2023.
//

import Foundation
import SwiftUI

struct TextLinkHandlerModifier: ViewModifier {
    let onTapUser: ((String) -> Void)?
    let onTapStoryId: ((Int) -> Void)?
    let onTapURL: ((URL) -> Void)?
    
    func body(content: Content) -> some View {
        content
        .environment(\.openURL, OpenURLAction { url in
            // TODO: Fix bug with woodruffw post
            
            /// Handle internal links to item pages
            if let idMatch = url.absoluteString.firstMatch(of: /news.ycombinator.com\/item\?id=([0-9]+)/),
               let idMatchInt = Int(idMatch.output.1),
               let onTapStoryId {
                onTapStoryId(idMatchInt)

            /// Handle internal links to user pages
            } else if let userMatch = url.absoluteString.firstMatch(of: /news.ycombinator.com\/user\?id=([a-zA-Z0-9]+)/),
                      let onTapUser {
                let userId = userMatch.output.1
                onTapUser(String(userId))
                
            /// Handle email addresses
            } else if let _ = url.absoluteString.firstMatch(of: /[A-Z0-9a-z]+([._%+-]{1}[A-Z0-9a-z]+)*@[A-Z0-9a-z]+([.-]{1}[A-Z0-9a-z]+)*(\\.[A-Za-z]{2,4}){0,1}/) {
                UIApplication.shared.open(url)
                
            } else {
                /// Otherwise fall through to generic URL handler (SafariView)
                if let onTapURL {
                    onTapURL(url)
                }
            }
            return .handled
        })
    }
}

