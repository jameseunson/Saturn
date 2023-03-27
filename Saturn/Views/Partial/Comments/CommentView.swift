//
//  CommentView.swift
//  Saturn
//
//  Created by James Eunson on 11/1/2023.
//

import Foundation
import SwiftUI

typealias OnToggleExpandedCompletion = (CommentViewModel, CommentExpandedState, Bool) -> Void

struct CommentView: View {
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
    
    let displaysStory: Bool
    
    static let collapsedHeight: CGFloat = 30
    
    @State private var navBarHeight: CGFloat = 0
    @State private var commentOnScreen: Bool = true
    @State private var dragOffset: CGFloat = 0
    
    init(expanded: Binding<CommentExpandedState>,
         comment: CommentViewModel,
         displaysStory: Bool = false,
         onTapOptions: @escaping (CommentViewModel) -> Void,
         onTapUser: ((String) -> Void)? = nil,
         onToggleExpanded: OnToggleExpandedCompletion? = nil,
         onTapStoryId: ((Int) -> Void)? = nil,
         onTapURL: ((URL) -> Void)? = nil,
         onTapVote: ((HTMLAPIVoteDirection) -> Void)? = nil) {
        _expanded = expanded
        self.comment = comment
        self.displaysStory = displaysStory
        self.onTapOptions = onTapOptions
        self.onTapUser = onTapUser
        self.onToggleExpanded = onToggleExpanded
        self.onTapStoryId = onTapStoryId
        self.onTapURL = onTapURL
        self.onTapVote = onTapVote
    }
    
    var body: some View {
        ZStack {
            if SaturnKeychainWrapper.shared.isLoggedIn,
               frameHeight > 0,
               abs(dragOffset) > 0 {
                VoteBackdropView(dragOffset: $dragOffset)
                    .transition(.identity)
            }
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
            .transition(.identity)
            .padding([.leading, .trailing], expanded == .hidden ? 0 : 10)
            .offset(.init(width: dragOffset, height: 0))
            .background {
                Color(UIColor.systemBackground)
                    .edgesIgnoringSafeArea(.all)
                    .offset(.init(width: dragOffset, height: 0))
            }
        }
        .contextMenu(menuItems: {
            if SaturnKeychainWrapper.shared.isLoggedIn {
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
                // TODO:
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
        .if(SaturnKeychainWrapper.shared.isLoggedIn, transform: { view in
            view.modifier(DragVoteGestureModifier(dragOffset: $dragOffset, onTapVote: onTapVote))
        })
        .coordinateSpace(name: String(comment.id))
        .background(GeometryReader { proxy -> Color in
            DispatchQueue.main.async {
                commentOnScreen = proxy.frame(in: .named(String(comment.id))).origin.y > (LayoutManager.default.statusBarHeight + navBarHeight + 10)
            }
            return Color.clear
        })
        .if(frameHeight == 0, transform: { view in
            view.background(GeometryReader { proxy -> Color in
                DispatchQueue.main.async {
                    let value = proxy.frame(in: .named(String(comment.id))).size.height
                    if value > CommentView.collapsedHeight { /// A value below 30 indicates the view is not yet complete laying out and we should ignore this value (as the header is 30px high alone)
                        frameHeight = value
                    }
                }
                return Color.clear
            })
        })
        .if(navBarHeight == 0, transform: { view in
            view.background(NavBarAccessor { navBar in
                navBarHeight = navBar.bounds.height
             })
        })
        .if(frameHeight > 0, transform: { view in
            view.modifier(AnimatingCellHeight(height: heightForExpandedState()))
        })
        .clipped()
        .padding([.top, .bottom], expanded == .hidden ? 0 : 10)
        .modifier(CommentExpandModifier(comment: comment,
                                        onToggleExpanded: onToggleExpanded,
                                        expanded: $expanded,
                                        commentOnScreen: $commentOnScreen))
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
