//
//  CommentHeaderView.swif.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 26/1/2023.
//

import Foundation
import SwiftUI

struct CommentHeaderView: View {
    let comment: CommentViewModel
    let formatter = RelativeDateTimeFormatter()
    
    let onTapOptions: (CommentViewModel) -> Void
    let onTapUser: ((String) -> Void)?
    let onToggleExpanded: ((CommentViewModel, CommentExpandedState) -> Void)?
    
    @Binding var expanded: CommentExpandedState
    
    var body: some View {
        ZStack {
            HStack {
                Text(comment.by)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(Color.accentColor)
                    .onTapGesture {
                        if let onTapUser {
                            onTapUser(comment.by)
                        }
                    }
                Spacer()
                Text(formatter.localizedString(for: comment.comment.time, relativeTo: Date()))
                    .font(.body)
                    .foregroundColor(.gray)
                if expanded == .expanded {
                    Image(systemName: "ellipsis")
                        .font(.body)
                        .foregroundColor(.gray)
                        .onTapGesture {
                            onTapOptions(comment)
                        }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation {
                    toggleExpanded()
                }
                if let onToggleExpanded {
                    onToggleExpanded(comment, expanded)
                }
            }
            
            if expanded == .collapsed {
                Rectangle()
                    .foregroundColor(.clear)
                    .contentShape(Rectangle())
                    .allowsHitTesting(true)
                    .onTapGesture {
                        withAnimation {
                            toggleExpanded()
                        }
                        if let onToggleExpanded {
                            onToggleExpanded(comment, expanded)
                        }
                    }
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

