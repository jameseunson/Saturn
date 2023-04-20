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
    
    @State var frameHeight: CGFloat = 0
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
    
    static let collapsedHeight: CGFloat = 40
    
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
        .transition(.identity)
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
        .coordinateSpace(name: String(comment.id))
        .background(GeometryReader { proxy -> Color in
            DispatchQueue.main.async {
                commentOnScreen = proxy.frame(in: .named(String(comment.id))).origin.y > (layoutManager.statusBarHeight + layoutManager.navBarHeight + 10)
            }
            return Color.clear
        })
        .if(frameHeight == 0, transform: { view in
            view.background(GeometryReader { proxy -> Color in
                DispatchQueue.main.async {
                    let value = proxy.frame(in: .named(String(comment.id))).size.height
                    if value > (CommentView.collapsedHeight + 10) { /// A value below 30 indicates the view is not yet complete laying out and we should ignore this value (as the header is 30px high alone)
                        frameHeight = value
                    }
                }
                return Color.clear
            })
        })
        .if(frameHeight > 0, transform: { view in
            view.modifier(AnimatingCellHeight(height: heightForExpandedState()))
        })
        .clipped()
        .padding(.top, expanded == .hidden ? 0 : 10)
        .padding(.bottom, expanded == .hidden ? 0 : 4)
        .modifier(CommentExpandModifier(comment: comment,
                                        onToggleExpanded: onToggleExpanded,
                                        expanded: $expanded,
                                        commentOnScreen: $commentOnScreen))
        .onReceive(keychainWrapper.isLoggedInSubject) { output in
            isLoggedIn = output
        }
    }
    
    func contentView() -> some View {
        VStack {
            HStack {
                if expanded == .hidden && comment.isAnimating == .none {
                    EmptyView()
                } else {
                    CommentIndentationView(comment: comment)
                        .opacity(comment.isAnimating == .collapsing ? 0.0 : 1.0)
                    VStack(alignment: .leading) {
                        CommentHeaderView(comment: comment,
                                          onTapOptions: onTapOptions,
                                          onTapUser: onTapUser,
                                          onToggleExpanded: onToggleExpanded,
                                          onTapVote: onTapVote,
                                          expanded: $expanded,
                                          commentOnScreen: $commentOnScreen)
                        Divider()
                        if expanded == .expanded {
                            Text(comment.comment.processedText ?? AttributedString())
                                .font(.body)
                                .modifier(TextLinkHandlerModifier(onTapUser: onTapUser,
                                                                  onTapStoryId: onTapStoryId,
                                                                  onTapURL: onTapURL))
                                .frame(height: frameHeight != 0 ? frameHeight - (CommentView.collapsedHeight + 10) : nil)
                        }
                    }
                }
            }
            Divider()
                .padding(.leading, CGFloat(comment.indendation) * 20)
                .opacity(context == .user || expanded != .expanded ? 0 : 1)
        }
        .padding([.leading, .trailing], expanded == .hidden ? 0 : 10)
        .drawingGroup()
    }
    
    func heightForExpandedState() -> CGFloat {
        switch expanded {
        case .expanded:
            return frameHeight
        case .collapsed:
            return CommentView.collapsedHeight
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
