//
//  StoryLoggedInOptionsView.swift
//  Saturn
//
//  Created by James Eunson on 17/4/2023.
//

import Foundation
import SwiftUI
import Factory

struct StoryLoggedInOptionsView: View {
    let story: StoryRowViewModel
    let onTapVote: ((HTMLAPIVoteDirection) -> Void)?
    let onTapSheet: ((StoryRowViewModel) -> Void)?
    
    var body: some View {
        HStack(alignment: .top) {
            Button {
                let impactMed = UIImpactFeedbackGenerator(style: .medium)
                impactMed.impactOccurred()
                
                onTapSheet?(story)
            } label: {
                HStack {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(height: 30)
            }
            .padding(.leading, 15)
            .frame(width: 66, height: 30)
            .contentShape(Rectangle())
            .buttonStyle(StoryLoggedInOptionsButtonStyle())
            
            Spacer()
            if let vote = story.vote,
               vote.directions.contains(.upvote) {
                Button {
                    let impactMed = UIImpactFeedbackGenerator(style: .medium)
                    impactMed.impactOccurred()
                    onTapVote?(.upvote)
                } label: {
                    Text(Image(systemName: "arrow.up"))
                        .font(.body)
                        .foregroundColor(vote.state == .upvote ? .accentColor : .gray)
                }
                .buttonStyle(StoryLoggedInOptionsButtonStyle())
            }
        }
        .frame(minHeight: 33)
    }
}

struct StoryLoggedInOptionsButtonStyle: ButtonStyle {
    public func makeBody(configuration: StoriesListButtonStyle.Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.8 : 1)
        
    }
}

struct StoryLoggedInOptionsView_Previews: PreviewProvider {
    static var previews: some View {
        StoryLoggedInOptionsView(story: StoryRowViewModel(story: Story.fakeStory()!, vote: HTMLAPIVote.fakeVote()), onTapVote: { _ in }, onTapSheet: { _ in })
    }
}
