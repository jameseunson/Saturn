//
//  CommentExpandModifier.swift
//  Saturn
//
//  Created by James Eunson on 26/1/2023.
//

import Foundation
import SwiftUI

struct CommentExpandModifier: ViewModifier {
    let comment: CommentViewModel
    let onToggleExpanded: OnToggleExpandedCompletion?
    
    @Binding var expanded: CommentExpandedState
    @Binding var commentOnScreen: Bool
    
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    toggleExpanded()
                }
                if let onToggleExpanded {
                    onToggleExpanded(comment, expanded, commentOnScreen)
                }
            }
    }
    
    func toggleExpanded() {
        switch expanded {
        case .expanded:
            expanded = .collapsed
        case .collapsed, .hidden:
            expanded = .expanded
        }
    }
}

