//
//  StoryContextSheetModifier.swift
//  Saturn
//
//  Created by James Eunson on 30/3/2023.
//

import Foundation
import SwiftUI

struct StoryContextSheetModifier: ViewModifier {
    @Binding var displayingConfirmSheetForStory: StoryRowViewModel?
    @Binding var selectedShareItem: StoryDetailShareItem?
    @Binding var selectedUser: String?
    
    let onTapVote: ((HTMLAPIVoteDirection) -> Void)?
    
    func body(content: Content) -> some View {
        content
            .confirmationDialog("Story", isPresented: createBoolBinding(from: $displayingConfirmSheetForStory), actions: {
                if let story = displayingConfirmSheetForStory {
                    if SaturnKeychainWrapper.shared.isLoggedIn,
                       let vote = story.vote {
                        if vote.directions.contains(.upvote) {
                            Button(action: {
                                onTapVote?(.unvote)
                            }, label: {
                                Label("Upvote", systemImage: "arrow.up")
                            })
                        }
                        if vote.directions.contains(.downvote) {
                            Button(action: {
                                onTapVote?(.downvote)
                            }, label: {
                                Label("Downvote", systemImage: "arrow.down")
                            })
                        }
                    }
                    Button(action: { selectedShareItem = .story(story) }, label:
                    {
                        Label("Share", systemImage: "square.and.arrow.up")
                    })
                    Button(action: { selectedUser = story.author }, label:
                    {
                        Label(story.author, systemImage: "person.circle")
                    })
                }
            })
    }
}
