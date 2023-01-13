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
    
    let onTapUser: (CommentViewModel) -> Void
    let onTapOptions: (CommentViewModel) -> Void
    let onToggleExpanded: (CommentViewModel, CommentExpandedState) -> Void
    
    @State var displayingSafariURL: URL?
    
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
                                    onTapUser(comment)
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
                                    onToggleExpanded(comment, expanded)
                                }
                        }
                    }
                    Divider()
                    if expanded == .expanded {
                        Text(comment.comment.text)
                            .font(.body)
                            .environment(\.openURL, OpenURLAction { url in
                                if url.host == "news.ycombinator.com" {
                                    // TODO:
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
                onToggleExpanded(comment, expanded)
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
        case .collapsed:
            expanded = .expanded
        case .hidden:
            expanded = .expanded
        }
    }
}
