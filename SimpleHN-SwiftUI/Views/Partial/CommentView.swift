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
        DisclosureGroup(isExpanded: isExpandedBinding()) {
            Text(comment.comment.processedText ?? AttributedString())
                .font(.body)
                .modifier(CommentLinkHandlerModifier(displayingSafariURL: $displayingSafariURL,
                                                     onTapUser: onTapUser,
                                                     onTapStoryId: onTapStoryId))
        } label: {
            CommentHeaderView(comment: comment,
                              onTapOptions: onTapOptions,
                              onTapUser: onTapUser,
                              onToggleExpanded: onToggleExpanded,
                              expanded: $expanded)
        }
        .disclosureGroupStyle(CustomDisclosureGroupStyle(comment: comment))
        .modifier(CommentExpandModifier(comment: comment,
                                        onToggleExpanded: onToggleExpanded,
                                        expanded: $expanded,
                                        displayingSafariURL: $displayingSafariURL))
    }
    
    func displayingSafariViewBinding() -> Binding<Bool> {
        Binding {
            displayingSafariURL != nil
        } set: { value in
            if !value { displayingSafariURL = nil }
        }
    }
    
    func isExpandedBinding() -> Binding<Bool> {
        Binding {
            expanded == .expanded
        } set: { value in
            expanded = value ? expanded : .collapsed
        }
    }
}

struct CommentIndentationView: View {
    let comment: CommentViewModel
    
    var body: some View {
        if comment.indendation > 0 {
            Spacer()
                .frame(width: CGFloat(comment.indendation) * 20)
            
            RoundedRectangle(cornerSize: .init(width: 1, height: 1))
                .frame(width: 2)
                .foregroundColor(.gray)
                .padding(.trailing, 5)
        } else {
            EmptyView()
        }
    }
}

struct CustomDisclosureGroupStyle: DisclosureGroupStyle {
    let comment: CommentViewModel
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            if comment.indendation > 0 {
                Spacer()
                    .frame(width: (CGFloat(comment.indendation) * 20))
            }
            configuration.label
            Spacer()
            Image(systemName: "chevron.down")
                .foregroundColor(.gray)
                .rotationEffect(.degrees(configuration.isExpanded ? 90 : 0))
        }
        if configuration.isExpanded {
            HStack {
                if comment.indendation > 0 {
                    Spacer()
                        .frame(width: CGFloat(comment.indendation) * 20)
                }
                configuration.content
                    .disclosureGroupStyle(self)
            }
        }
    }
}
