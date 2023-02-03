//
//  CommentView.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 11/1/2023.
//

import Foundation
import SwiftUI

struct CommentView: View {
    @State var frameHeight: CGFloat = 0
    @Binding var expanded: CommentExpandedState
    
    let formatter = RelativeDateTimeFormatter()
    let comment: CommentViewModel
    
    let onTapOptions: (CommentViewModel) -> Void
    let onTapUser: ((String) -> Void)?
    let onToggleExpanded: ((CommentViewModel, CommentExpandedState) -> Void)?
    let onTapStoryId: ((Int) -> Void)?
    let onTapURL: ((URL) -> Void)?
    
    let displaysStory: Bool
    
    static let collapsedHeight: CGFloat = 30
    
    init(expanded: Binding<CommentExpandedState>,
         comment: CommentViewModel,
         displaysStory: Bool = false,
         onTapOptions: @escaping (CommentViewModel) -> Void,
         onTapUser: ((String) -> Void)? = nil,
         onToggleExpanded: ((CommentViewModel, CommentExpandedState) -> Void)? = nil,
         onTapStoryId: ((Int) -> Void)? = nil,
         onTapURL: ((URL) -> Void)? = nil) {
        _expanded = expanded
        self.comment = comment
        self.displaysStory = displaysStory
        self.onTapOptions = onTapOptions
        self.onTapUser = onTapUser
        self.onToggleExpanded = onToggleExpanded
        self.onTapStoryId = onTapStoryId
        self.onTapURL = onTapURL
    }
    
    var body: some View {
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
                                      expanded: $expanded)
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
        .contextMenu(menuItems: {
            Button(action: {
                
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
            if frameHeight == 0 {
                DispatchQueue.main.async {
                    let value = proxy.frame(in: .named(String(comment.id))).size.height
                    if value > CommentView.collapsedHeight { /// A value below 30 indicates the view is not yet complete laying out and we should ignore this value (as the header is 30px high alone)
                        frameHeight = value
                    }
                }
            }
            return Color.clear
        })
        .if(frameHeight > 0, transform: { view in
            view.modifier(AnimatingCellHeight(height: heightForExpandedState()))
        })
        .clipped()
        .padding(expanded == .hidden ? 0 : 10)
        .modifier(CommentExpandModifier(comment: comment,
                                        onToggleExpanded: onToggleExpanded,
                                        expanded: $expanded))
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

struct AnimatingCellHeight: ViewModifier, Animatable {
    var height: CGFloat = 0
    
    private var target: CGFloat
    private var onEnded: () -> ()

    init(height: CGFloat, onEnded: @escaping () -> () = {}) {
        self.target = height
        self.height = height
        self.onEnded = onEnded // << callback
    }

    var animatableData: CGFloat {
        get { height }
        set {
            height = newValue
            if newValue == target {
                onEnded()
            }
        }
    }

    func body(content: Content) -> some View {
        content.frame(height: height)
    }
}
