//
//  CommentView.swift
//  Saturn
//
//  Created by James Eunson on 11/1/2023.
//

import Foundation
import SwiftUI
import Factory
import SwipeActions

typealias OnToggleExpandedCompletion = (CommentViewModel, CommentExpandedState, Bool) -> Void

struct CommentView: View {
    @Injected(\.layoutManager) private var layoutManager
    @Injected(\.keychainWrapper) private var keychainWrapper
    
    @Binding var expanded: CommentExpandedState
    
    let formatter = RelativeDateTimeFormatter()
    let comment: CommentViewModel
    
    let onTapOptions: (CommentViewModel) -> Void
    let onTapUser: ((String) -> Void)?
    let onToggleExpanded: ((CommentViewModel, CommentExpandedState, Bool) -> Void)?
    let onTapStoryId: ((Int) -> Void)?
    let onTapURL: ((URL) -> Void)?
    let onTapVote: ((HTMLAPIVoteDirection) -> Void)?
    let onTapShare: ((CommentViewModel) -> Void)?
    
    let displaysStory: Bool
    let isHighlighted: Bool
    let context: CommentViewContext
    
    static let collapsedHeight: CGFloat = 44
    
    @State private var commentOnScreen: Bool = true
    @State private var isLoggedIn: Bool = false
    
    init(expanded: Binding<CommentExpandedState>,
         comment: CommentViewModel,
         displaysStory: Bool = false,
         isHighlighted: Bool = false,
         context: CommentViewContext = .storyDetail,
         onTapOptions: @escaping (CommentViewModel) -> Void,
         onTapUser: ((String) -> Void)? = nil,
         onToggleExpanded: OnToggleExpandedCompletion? = nil,
         onTapStoryId: ((Int) -> Void)? = nil,
         onTapURL: ((URL) -> Void)? = nil,
         onTapVote: ((HTMLAPIVoteDirection) -> Void)? = nil,
         onTapShare: ((CommentViewModel) -> Void)? = nil) {
        _expanded = expanded
        self.comment = comment
        self.displaysStory = displaysStory
        self.isHighlighted = isHighlighted
        self.context = context
        self.onTapOptions = onTapOptions
        self.onTapUser = onTapUser
        self.onToggleExpanded = onToggleExpanded
        self.onTapStoryId = onTapStoryId
        self.onTapURL = onTapURL
        self.onTapVote = onTapVote
        self.onTapShare = onTapShare
        _isLoggedIn = .init(initialValue: keychainWrapper.isLoggedIn)
    }
    
    var body: some View {
        VStack {
            if comment.isAnimating == .none {
                SwipeView {
                    contentView()
                    
                } leadingActions: { context in
                    if isLoggedIn,
                       self.context != .user,
                       let vote = comment.vote,
                       vote.directions.contains(.upvote) {
                        SwipeAction.action(direction: .upvote, onTapVote: onTapVote, context: context)
                    }
                } trailingActions: { context in
                    if isLoggedIn,
                       self.context != .user,
                       let vote = comment.vote,
                       vote.directions.contains(.downvote) {
                        SwipeAction.action(direction: .downvote, onTapVote: onTapVote, context: context)
                    }
                }
                .swipeDefaults()
            } else {
                contentView()
            }
        }
        .background {
            if isHighlighted {
                Color.indentationColor()
                    .opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .padding(.leading, CGFloat(comment.indendation) * 20)
            } else {
                Color(UIColor.systemBackground)
                    .edgesIgnoringSafeArea(.all)
            }
        }
        .contextMenu(menuItems: {
            if isLoggedIn {
                Button(action: {
                    onTapVote?(.upvote)
                }, label: {
                    Label("Upvote", systemImage: "arrow.up")
                })
                Button(action: {
                    onTapVote?(.downvote)
                }, label: {
                    Label("Downvote", systemImage: "arrow.down")
                })
            }
            Button(action: {
                onTapShare?(comment)
            }, label: {
                Label("Share", systemImage: "square.and.arrow.up")
            })
            Button(action: {
                if let onTapUser {
                    onTapUser(comment.by)
                }
            }, label: {
                Label(comment.by, systemImage: "person.circle")
            })
        })
        .modifier(CommentExpandModifier(comment: comment,
                                        onToggleExpanded: onToggleExpanded,
                                        expanded: $expanded,
                                        commentOnScreen: $commentOnScreen))
        .onReceive(keychainWrapper.isLoggedInSubject) { output in
            isLoggedIn = output
        }
    }
    
    func contentView() -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                CommentIndentationView(comment: comment)
                Spacer()
                    .frame(width: 10)
                VStack(alignment: .leading, spacing: 0) {
                    CommentHeaderView(comment: comment,
                                      onTapOptions: onTapOptions,
                                      onTapUser: onTapUser,
                                      onToggleExpanded: onToggleExpanded,
                                      onTapVote: onTapVote,
                                      expanded: $expanded,
                                      commentOnScreen: $commentOnScreen)
                    .frame(height: CommentView.collapsedHeight)
                    
                    if expanded == .expanded {
                        Spacer()
                            .frame(height: 10)
                        Text(comment.comment.processedText ?? AttributedString())
                            .font(.body)
                            .opacity(expanded == .expanded ? 1 : 0)
                            .padding(.trailing, 10)
                            .fixedSize(horizontal: false, vertical: true)
                            .modifier(TextLinkHandlerModifier(onTapUser: onTapUser,
                                                              onTapStoryId: onTapStoryId,
                                                              onTapURL: onTapURL))
                    }
                }
            }
            if expanded == .expanded,
               context != .user {
                Divider()
                    .padding(.top, 10)
                    .padding(.bottom, 5)
                    .padding(.leading, CGFloat(comment.indendation) * 20)
            }
        }
        .coordinateSpace(name: String(comment.id))
        .background(GeometryReader { proxy -> Color in
            DispatchQueue.main.async {
                commentOnScreen = proxy.frame(in: .named(String(comment.id))).origin.y > (layoutManager.statusBarHeight + layoutManager.navBarHeight + 10)
            }
            return Color.clear
        })
        .opacity(expanded == .hidden ? 0 : 1)
        .scaleEffect(x: 1, y: expanded == .hidden ? 0 : 1, anchor: .top)
        .frame(height: heightForExpandedState(), alignment: .top)
        .clipped()
        .drawingGroup()
    }
    
    func heightForExpandedState() -> CGFloat? {
        switch expanded {
        case .expanded:
            return nil
        case .collapsed:
            return CommentView.collapsedHeight + 10
        case .hidden:
            return 0
        }
    }
}

struct CommentView_Previews: PreviewProvider {
    static var previews: some View {
        CommentView(expanded: .constant(.expanded), comment: CommentViewModel.fakeComment()) { _ in }
        CommentView(expanded: .constant(.expanded), comment: CommentViewModel.fakeCommentWithScore()) { _ in }
    }
}

enum CommentViewContext {
    case storyDetail
    case user
}
