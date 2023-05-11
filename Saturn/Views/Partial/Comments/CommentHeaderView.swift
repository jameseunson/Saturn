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
    let onTapVote: ((HTMLAPIVoteDirection) -> Void)?
    
    @Binding var expanded: CommentExpandedState
    @Binding var commentOnScreen: Bool
    
    init(comment: CommentViewModel,
         onTapOptions: ((CommentViewModel) -> Void)? = nil,
         onTapUser: ( (String) -> Void)? = nil,
         onToggleExpanded: OnToggleExpandedCompletion? = nil,
         onTapVote: ((HTMLAPIVoteDirection) -> Void)? = nil,
         expanded: Binding<CommentExpandedState>,
         commentOnScreen: Binding<Bool>) {
        self.comment = comment
        self.onTapOptions = onTapOptions
        self.onTapUser = onTapUser
        self.onToggleExpanded = onToggleExpanded
        self.onTapVote = onTapVote
        _expanded = expanded
        _commentOnScreen = commentOnScreen
    }
    
    var body: some View {
        VStack {
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
                if let vote = comment.vote {
                    if vote.directions.contains(.upvote) {
                        Button {
                            print("upvote \(comment.id)")
                            let impactMed = UIImpactFeedbackGenerator(style: .medium)
                            impactMed.impactOccurred()
                            onTapVote?(.upvote)
                        } label: {
                            Text(Image(systemName: "arrow.up"))
                                .font(.callout)
                                .foregroundColor(vote.state == .upvote ? .accentColor : .gray)
                        }
                        .buttonStyle(StoryLoggedInOptionsButtonStyle())
                    }
                    if vote.directions.contains(.downvote) {
                        Button {
                            print("downvote \(comment.id)")
                            onTapVote?(.downvote)
                            let impactMed = UIImpactFeedbackGenerator(style: .medium)
                            impactMed.impactOccurred()
                        } label: {
                            Text(Image(systemName: "arrow.down"))
                                .font(.callout)
                                .foregroundColor(vote.state == .downvote ? .blue : .gray)
                        }
                        .buttonStyle(StoryLoggedInOptionsButtonStyle())
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
                    Button {
                        let impactMed = UIImpactFeedbackGenerator(style: .medium)
                        impactMed.impactOccurred()
                        if let onTapOptions {
                            onTapOptions(comment)
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.body)
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(StoryLoggedInOptionsButtonStyle())
                    
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
            .overlay {
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
            .padding(.top, 8)
            Divider()
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
