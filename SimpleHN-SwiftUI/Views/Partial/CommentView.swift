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
    
    @State var displayingSafariURL: URL?
    @State var displayingInternalStoryId: Int?
    
    init(expanded: Binding<CommentExpandedState>,
         comment: CommentViewModel,
         onTapOptions: @escaping (CommentViewModel) -> Void,
         onTapUser: ((String) -> Void)? = nil,
         onToggleExpanded: ((CommentViewModel, CommentExpandedState) -> Void)? = nil) {
        _expanded = expanded
        self.comment = comment
        self.onTapOptions = onTapOptions
        self.onTapUser = onTapUser
        self.onToggleExpanded = onToggleExpanded
    }
    
    var body: some View {
        if expanded == .hidden {
            EmptyView()
        } else {
            HStack {
                Spacer()
                    .frame(width: CGFloat(comment.indendation) * 20)
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
                            .environment(\.openURL, OpenURLAction { url in
                                if let idMatch = url.absoluteString.firstMatch(of: /news.ycombinator.com\/item\?id=([0-9]+)/),
                                   let idMatchInt = Int(idMatch.output.1) {
                                    displayingInternalStoryId = idMatchInt
                                    
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
            .navigationDestination(isPresented: displayingInternalStoryIdBinding()) {
                if let displayingInternalStoryId {
                    let interactor = StoryDetailInteractor(storyId: displayingInternalStoryId)
                    StoryDetailView(interactor: interactor)
                } else {
                    EmptyView()
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
    
    func displayingInternalStoryIdBinding() -> Binding<Bool> {
        Binding {
            displayingInternalStoryId != nil
        } set: { value in
            if !value { displayingInternalStoryId = nil }
        }
    }
    
    func toggleExpanded() {
        switch expanded {
        case .expanded:
            expanded = .collapsed
        case .collapsed:
            expanded = .expanded
        case .hidden:
            expanded = .expanded
        }
    }
}
