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
        if expanded == .hidden {
            EmptyView()
            
        } else {
            HStack {
                if comment.indendation > 0 {
                    Spacer()
                        .frame(width: CGFloat(comment.indendation) * 20)
                    
                    RoundedRectangle(cornerSize: .init(width: 1, height: 1))
                        .frame(width: 2)
                        .foregroundColor(.gray)
                        .padding(.trailing, 5)
                }
                
                VStack(alignment: .leading) {
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
                    Divider()
                    if expanded == .expanded {
                        Text(comment.comment.text)
                            .font(.body)
                            .modifier(CommentLinkHandlerModifier(displayingSafariURL: $displayingSafariURL,
                                                                 onTapUser: onTapUser,
                                                                 onTapStoryId: onTapStoryId))
                    }
                    
//                    if displaysStory {
//                        Rectangle()
//                            .foregroundColor(.gray)
//                            .cornerRadius(8)
//                            .padding([.top, .bottom])
//                            .frame(height: 50)
//                    }
                }
            }
            .onTapGesture {
                withAnimation {
                    toggleExpanded()
                }
                if let onToggleExpanded {
                    onToggleExpanded(comment, expanded)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .frame(height: expanded == .expanded ? nil : 20)
            .sheet(isPresented: displayingSafariViewBinding()) {
                if let displayingSafariURL {
                    SafariView(url: displayingSafariURL)
                        .ignoresSafeArea()
                }
            }
        }
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
}

struct CommentLinkHandlerModifier: ViewModifier {
    @Binding var displayingSafariURL: URL?
    
    let onTapUser: ((String) -> Void)?
    let onTapStoryId: ((Int) -> Void)?
    
    func body(content: Content) -> some View {
        content
        .environment(\.openURL, OpenURLAction { url in
            // TODO: Fix bug with woodruffw post
            
            if let idMatch = url.absoluteString.firstMatch(of: /news.ycombinator.com\/item\?id=([0-9]+)/),
               let idMatchInt = Int(idMatch.output.1),
               let onTapStoryId {
                onTapStoryId(idMatchInt)
                
            } else if let userMatch = url.absoluteString.firstMatch(of: /news.ycombinator.com\/user\?id=([a-zA-Z0-9]+)/),
                      let onTapUser {
                let userId = userMatch.output.1
                onTapUser(String(userId))
                
            } else {
                displayingSafariURL = url
            }
            return .handled
        })
    }
}
