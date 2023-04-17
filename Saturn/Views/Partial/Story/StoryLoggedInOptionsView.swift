//
//  StoryLoggedInOptionsView.swift
//  Saturn
//
//  Created by James Eunson on 17/4/2023.
//

import Foundation
import SwiftUI

struct StoryLoggedInOptionsView: View {
    let story: StoryRowViewModel
    let onTapVote: ((HTMLAPIVoteDirection) -> Void)?
    let onTapSheet: ((StoryRowViewModel) -> Void)?
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "ellipsis")
                .contentShape(Rectangle())
                .font(.body)
                .foregroundColor(.gray)
                .frame(width: 30, height: 30)
                .onTapGesture {
                    let impactMed = UIImpactFeedbackGenerator(style: .medium)
                    impactMed.impactOccurred()
                    
                    onTapSheet?(story)
                }
            Spacer()
            if let vote = story.vote {
                if vote.directions.contains(.upvote) {
                    Button {
                        let impactMed = UIImpactFeedbackGenerator(style: .medium)
                        impactMed.impactOccurred()
                        onTapVote?(.upvote)
                    } label: {
                        Text(Image(systemName: "arrow.up"))
                            .font(.body)
                            .foregroundColor(vote.state == .upvote ? .accentColor : .gray)
                    }
                }
                if vote.directions.contains(.downvote) {
                    Button {
                        let impactMed = UIImpactFeedbackGenerator(style: .medium)
                        impactMed.impactOccurred()
                        onTapVote?(.downvote)
                    } label: {
                        Text(Image(systemName: "arrow.down"))
                            .font(.body)
                            .foregroundColor(vote.state == .downvote ? .blue : .gray)
                    }
                }
            }
        }
        .frame(minHeight: 33)
    }
}
