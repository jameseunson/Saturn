//
//  CommentHeaderView.swif.swift
//  Saturn
//
//  Created by James Eunson on 26/1/2023.
//

import Foundation
import SwiftUI

struct CommentHeaderView: View {
    let comment: CommentViewModel
    
    let onTapOptions: ((CommentViewModel) -> Void)?
    let onTapUser: ((String) -> Void)?
    let onToggleExpanded: OnToggleExpandedCompletion?
    
    @Binding var expanded: CommentExpandedState
    @Binding var commentOnScreen: Bool
    
    init(comment: CommentViewModel,
         onTapOptions: ((CommentViewModel) -> Void)? = nil,
         onTapUser: ( (String) -> Void)? = nil,
         onToggleExpanded: OnToggleExpandedCompletion? = nil,
         expanded: Binding<CommentExpandedState>,
         commentOnScreen: Binding<Bool>) {
        self.comment = comment
        self.onTapOptions = onTapOptions
        self.onTapUser = onTapUser
        self.onToggleExpanded = onToggleExpanded
        _expanded = expanded
        _commentOnScreen = commentOnScreen
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
                    if let score = comment.score {
                        Text(String(score)).foregroundColor(.gray)
                        + Text(" ")
                        + Text(Image(systemName: "arrow.up.square.fill")).foregroundColor(.gray)
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
                        
                    } else if comment.totalChildCount > 0 {
                        Text(String(comment.totalChildCount))
                            .font(.callout)
                            .foregroundColor(.gray)
                            .padding([.leading, .trailing], 4)
                            .padding([.top, .bottom], 0)
                            .background {
                                RoundedRectangle(cornerRadius: 6)
                                    .foregroundColor( Color(UIColor.systemGray6) )
                            }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        toggleExpanded()
                    }
                    if let onToggleExpanded {
                        onToggleExpanded(comment, expanded, commentOnScreen)
                    }
                }
                
                if expanded == .collapsed {
                    Rectangle()
                        .foregroundColor(.clear)
                        .contentShape(Rectangle())
                        .allowsHitTesting(true)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                toggleExpanded()
                            }
                            if let onToggleExpanded {
                                onToggleExpanded(comment, expanded, commentOnScreen)
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
