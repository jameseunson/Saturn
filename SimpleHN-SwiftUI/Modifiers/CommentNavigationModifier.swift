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
        .navigationDestination(isPresented: content.createBoolBinding(from: $selectedUser)) {
            if let selectedUser {
                UserView(interactor: UserInteractor(username: selectedUser))
                    .navigationTitle(selectedUser)
            } else {
                EmptyView()
            }
        }
        .navigationDestination(isPresented: content.createBoolBinding(from: $displayingInternalStoryId)) {
            if let displayingInternalStoryId {
                StoryDetailView(interactor: StoryDetailInteractor(itemId: displayingInternalStoryId))
            } else {
                EmptyView()
            }
        }
        .confirmationDialog("User", isPresented: content.createBoolBinding(from: $selectedComment), actions: {
            if let selectedComment {
                Button(selectedComment.by) {
                    selectedUser = selectedComment.by
                }
                Button("Share Comment") {
                    selectedShareItem = .comment(selectedComment)
                }
            }
        })
        .sheet(isPresented: content.createBoolBinding(from: $selectedShareItem), content: {
            if let url = selectedShareItem?.url {
                let sheet = ActivityViewController(itemsToShare: [url])
                    .ignoresSafeArea()
                sheet.presentationDetents([.medium])
            }
        })
    }
}

