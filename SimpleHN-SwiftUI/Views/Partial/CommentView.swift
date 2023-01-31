//
//  CommentView.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 11/1/2023.
//

import Foundation
import SwiftUI

struct CommentView: View {
    @Binding var expanded: CommentExpandedState
    
    let formatter = RelativeDateTimeFormatter()
    let comment: CommentViewModel
    
    let onTapOptions: (CommentViewModel) -> Void
    let onTapUser: ((String) -> Void)?
    let onToggleExpanded: ((CommentViewModel, CommentExpandedState) -> Void)?
    let onTapStoryId: ((Int) -> Void)?
    let onTapURL: ((URL) -> Void)?
    
    let displaysStory: Bool
    
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
            if expanded == .hidden {
                EmptyView()
            } else {
                CommentIndentationView(comment: comment)
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
                    }
                }
            }
        }
//        .background {
//            Rectangle()
//                .foregroundColor(Color.random)
//        }
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
        .frame(height: heightForExpandedState())
        .clipped()
        .padding(expanded == .hidden ? 0 : 10)
        .modifier(CommentExpandModifier(comment: comment,
                                        onToggleExpanded: onToggleExpanded,
                                        expanded: $expanded))
    }
    
    func heightForExpandedState() -> CGFloat? {
        switch expanded {
        case .expanded:
            return nil
        case .collapsed:
            return 30
        case .hidden:
            return 0
        }
    }
}

extension Color {
    static var random: Color {
        return Color(
            red: .random(in: 0...1),
            green: .random(in: 0...1),
            blue: .random(in: 0...1)
        )
    }
}
