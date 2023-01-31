//
//  CommentExpandModifier.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 26/1/2023.
//

import Foundation
import SwiftUI

struct CommentExpandModifier: ViewModifier {
    let comment: CommentViewModel
    let onToggleExpanded: ((CommentViewModel, CommentExpandedState) -> Void)?
    
    @Binding var expanded: CommentExpandedState
    
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                withAnimation {
                    toggleExpanded()
                }
                if let onToggleExpanded {
                    onToggleExpanded(comment, expanded)
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

