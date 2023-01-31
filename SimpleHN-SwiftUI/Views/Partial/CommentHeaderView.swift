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
    
    let onTapOptions: ((CommentViewModel) -> Void)?
    let onTapUser: ((String) -> Void)?
    let onToggleExpanded: ((CommentViewModel, CommentExpandedState) -> Void)?
    
    @Binding var expanded: CommentExpandedState
    
    init(comment: CommentViewModel,
         onTapOptions: ((CommentViewModel) -> Void)? = nil,
         onTapUser: ( (String) -> Void)? = nil,
         onToggleExpanded: ((CommentViewModel, CommentExpandedState) -> Void)? = nil,
         expanded: Binding<CommentExpandedState>) {
        self.comment = comment
        self.onTapOptions = onTapOptions
        self.onTapUser = onTapUser
        self.onToggleExpanded = onToggleExpanded
        _expanded = expanded
    }
    
    var body: some View {
        if expanded == .hidden {
            EmptyView()
        } else {
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
                    Text(comment.relativeTimeString)
                        .font(.body)
                        .foregroundColor(.gray)
                    if expanded == .expanded {
                        Image(systemName: "ellipsis")
                            .font(.body)
                            .foregroundColor(.gray)
                            .onTapGesture {
                                let impactMed = UIImpactFeedbackGenerator(style: .medium)
                                impactMed.impactOccurred()
                                if let onTapOptions {
                                    onTapOptions(comment)
                                }
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

