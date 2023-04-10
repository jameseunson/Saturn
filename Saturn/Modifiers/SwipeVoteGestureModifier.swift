//
//  SwipeVoteGestureModifier.swift
//  Saturn
//
//  Created by James Eunson on 24/3/2023.
//

import Foundation
import SwiftUI

struct SwipeVoteGestureModifier: ViewModifier {
    @State var gestureComplete: Bool = false
    @Binding var dragOffset: CGFloat
    
    let onTapVote: ((HTMLAPIVoteDirection) -> Void)?
    let directionsEnabled: [HTMLAPIVoteDirection]
    
    let gestureCompleteThreshold: CGFloat = 80
    
    func body(content: Content) -> some View {
        content.gesture(DragGesture(minimumDistance: 30, coordinateSpace: .local)
            .onChanged({ value in
                withAnimation {
                    let width = value.translation.width
                    let absWidth = abs(width)
                    
                    /// Cap maximum swipe at a quarter of screen width
                    if absWidth < (UIScreen.main.bounds.size.width / 4) {
                        dragOffset = width
                    }
                    
                    /// If swipe exceeds a threshold, gesture is considered 'completed'
                    /// and haptic feedback is given
                    if absWidth > gestureCompleteThreshold,
                       !gestureComplete {
                        gestureComplete = true
                        
                        /// Check whether the direction of swipe is allowed or not
                        /// If not, do not register haptic feedback or perform callback
                        if width > 0,
                           !directionsEnabled.contains(.upvote) {
                            let errorFeedback = UINotificationFeedbackGenerator()
                            errorFeedback.notificationOccurred(.error)
                            return
                        }
                        if width < 0,
                           !directionsEnabled.contains(.downvote) {
                            let errorFeedback = UINotificationFeedbackGenerator()
                            errorFeedback.notificationOccurred(.error)
                            return
                        }
                        
                        let impactMed = UIImpactFeedbackGenerator(style: .medium)
                        impactMed.impactOccurred()
                        
                        /// Perform callback action for upvote or downvote,
                        /// depending on direction of swipe
                        if width > gestureCompleteThreshold {
                            onTapVote?(.upvote)
                        }
                        if width < -gestureCompleteThreshold {
                            onTapVote?(.downvote)
                        }
                    }
                }
            }).onEnded({ value in
                /// Reset x translation when user releases drag
                if abs(value.translation.width) > 0 {
                    withAnimation {
                        dragOffset = 0
                    }
                }
                /// Reset gesture
                gestureComplete = false
        }))
    }
}
