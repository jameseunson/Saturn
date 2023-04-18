//
//  SwipeView+StandardConfig.swift
//  Saturn
//
//  Created by James Eunson on 17/4/2023.
//

import Foundation
import SwiftUI
import SwipeActions

extension SwipeView {
    func swipeDefaults() -> some View {
        self
            .swipeActionsStyle(.mask)
            .swipeActionCornerRadius(0)
            .swipeSpacing(0)
            .swipeActionsMaskCornerRadius(0)
            .swipeMinimumDistance(30)
            .swipeReadyToExpandPadding(0)
            .swipeReadyToTriggerPadding(0)
            .swipeMinimumPointToTrigger(0)
            .swipeEnableTriggerHaptics(true)
    }
}

extension SwipeAction where Label == Image, Background == Color {
    static func action(direction: HTMLAPIVoteDirection,
                       onTapVote: ((HTMLAPIVoteDirection) -> Void)?,
                       context: SwipeContext) -> some View {
        
        let imageName = direction == .upvote ? "arrow.up.square.fill" : "arrow.down.square.fill"
        let color: Color = direction == .upvote ? .accentColor : .blue
        
        return SwipeAction(
            systemImage: imageName,
            backgroundColor: color
        ) {
            onTapVote?(direction)
            context.state.wrappedValue = .closed
        }
        .allowSwipeToTrigger()
        .font(.title.weight(.bold))
        .foregroundColor(.white)
    }
}
