//
//  CommentLinkHandlerModifier.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 25/1/2023.
//

import Foundation
import SwiftUI

struct CommentLinkHandlerModifier: ViewModifier {
    @Binding var displayingSafariURL: URL?
    
    let onTapUser: ((String) -> Void)?
    let onTapStoryId: ((Int) -> Void)?
    
    func body(content: Content) -> some View {
        content
        .environment(\.openURL, OpenURLAction { url in
            // TODO: Fix bug with woodruffw post
            
            if let idMatch = url.absoluteString.firstMatch(of: /news.ycombinator.com\/item\?id=([0-9]+)/),
               let idMatchInt = Int(idMatch.output.1),
               let onTapStoryId {
                onTapStoryId(idMatchInt)
                
            } else if let userMatch = url.absoluteString.firstMatch(of: /news.ycombinator.com\/user\?id=([a-zA-Z0-9]+)/),
                      let onTapUser {
                let userId = userMatch.output.1
                onTapUser(String(userId))
                
            } else {
                displayingSafariURL = url
            }
            return .handled
        })
    }
}

