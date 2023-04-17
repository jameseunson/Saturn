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
