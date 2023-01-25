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
    
    let comment: CommentViewModel
    
    let onTapOptions: (CommentViewModel) -> Void
    let onTapUser: ((String) -> Void)?
    let onToggleExpanded: ((CommentViewModel, CommentExpandedState) -> Void)?
    let onTapStoryId: ((Int) -> Void)?
    
    let displaysStory: Bool
    
    @State var displayingSafariURL: URL?
    
    init(expanded: Binding<CommentExpandedState>,
         comment: CommentViewModel,
         displaysStory: Bool = false,
         onTapOptions: @escaping (CommentViewModel) -> Void,
         onTapUser: ((String) -> Void)? = nil,
         onToggleExpanded: ((CommentViewModel, CommentExpandedState) -> Void)? = nil,
         onTapStoryId: ((Int) -> Void)? = nil) {
        _expanded = expanded
        self.comment = comment
        self.displaysStory = displaysStory
        self.onTapOptions = onTapOptions
        self.onTapUser = onTapUser
        self.onToggleExpanded = onToggleExpanded
        self.onTapStoryId = onTapStoryId
    }
    
    var body: some View {
        HStack {
            if comment.indendation > 0 {
                Spacer()
                    .frame(width: CGFloat(comment.indendation) * 20)
                
                RoundedRectangle(cornerSize: .init(width: 1, height: 1))
                    .frame(width: 2)
                    .foregroundColor(.gray)
                    .padding(.trailing, 5)
                    .opacity(expanded == .expanded || expanded == .collapsed ? 1.0 : 0.0)
            }
            
            VStack(alignment: .leading) {
                CommentHeaderView(comment: comment,
                                  onTapOptions: onTapOptions,
                                  onTapUser: onTapUser,
                                  onToggleExpanded: onToggleExpanded,
                                  expanded: $expanded)
                .opacity(expanded == .expanded || expanded == .collapsed ? 1.0 : 0.0)
                
                Divider()
                if expanded == .expanded {
                    Text(comment.comment.text)
                        .font(.body)
                        .opacity(expanded == .expanded ? 1.0 : 0.0)
                        .modifier(CommentLinkHandlerModifier(displayingSafariURL: $displayingSafariURL,
                                                             onTapUser: onTapUser,
                                                             onTapStoryId: onTapStoryId))
                }
            }
        }
        .onTapGesture {
            toggleExpanded()
            if let onToggleExpanded {
                onToggleExpanded(comment, expanded)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(height: heightForExpandedState())
        .clipped()
        .sheet(isPresented: displayingSafariViewBinding()) {
            if let displayingSafariURL {
                SafariView(url: displayingSafariURL)
                    .ignoresSafeArea()
            }
        }
        .animation(.spring(response: 0.3))
        .padding(paddingForExpandedState())
    }
    
    func displayingSafariViewBinding() -> Binding<Bool> {
        Binding {
            displayingSafariURL != nil
        } set: { value in
            if !value { displayingSafariURL = nil }
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
    
    func heightForExpandedState() -> CGFloat? {
        switch expanded {
        case .expanded:
            return nil
        case .collapsed:
            return 35
        case .hidden:
            return 0
        }
    }
    
    func paddingForExpandedState() -> CGFloat {
        switch expanded {
        case .expanded, .collapsed:
            return 10
        case .hidden:
            return 0
        }
    }
}

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
                    Button {
                        onTapOptions(comment)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.body)
                            .foregroundColor(.gray)
                    }
                } else {
                    Image(systemName: "chevron.down")
                        .font(.body)
                        .foregroundColor(.gray)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                toggleExpanded()
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
                        toggleExpanded()
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
