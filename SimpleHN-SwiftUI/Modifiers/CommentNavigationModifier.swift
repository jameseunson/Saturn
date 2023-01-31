//
//  CommentNavigationModifier.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 20/1/2023.
//

import Foundation
import SwiftUI

struct CommentNavigationModifier: ViewModifier {
    @Binding var selectedShareItem: StoryDetailShareItem?
    @Binding var selectedUser: String?
    @Binding var displayingInternalStoryId: Int?
    @Binding var selectedComment: CommentViewModel?
    
    func body(content: Content) -> some View {
        content
        .navigationDestination(isPresented: displayingUserBinding()) {
            if let selectedUser {
                UserView(interactor: UserInteractor(username: selectedUser))
                    .navigationTitle(selectedUser)
            } else {
                EmptyView()
            }
        }
        .navigationDestination(isPresented: displayingInternalStoryIdBinding()) {
            if let displayingInternalStoryId {
                StoryDetailView(interactor: StoryDetailInteractor(storyId: displayingInternalStoryId))
            } else {
                EmptyView()
            }
        }
        .confirmationDialog("User", isPresented: displayingCommentSheet(), actions: {
            if let selectedComment {
                Button(selectedComment.by) {
                    selectedUser = selectedComment.by
                }
                Button("Share Comment") {
                    selectedShareItem = .comment(selectedComment)
                }
            }
        })
        .sheet(isPresented: isShareVisible(), content: {
            if let url = selectedShareItem?.url {
                let sheet = ActivityViewController(itemsToShare: [url])
                    .ignoresSafeArea()
                sheet.presentationDetents([.medium])
            }
        })
    }
    
    func displayingUserBinding() -> Binding<Bool> {
        Binding {
            selectedUser != nil
        } set: { value in
            if !value { selectedUser = nil }
        }
    }
    
    func displayingInternalStoryIdBinding() -> Binding<Bool> {
        Binding {
            displayingInternalStoryId != nil
        } set: { value in
            if !value { displayingInternalStoryId = nil }
        }
    }
    
    
    func displayingCommentSheet() -> Binding<Bool> {
        Binding {
            selectedComment != nil
        } set: { value in
            if !value { selectedComment = nil }
        }
    }
    
    func isShareVisible() -> Binding<Bool> {
        Binding {
            selectedShareItem != nil
        } set: { value in
            if !value { selectedShareItem = nil }
        }
    }
}

