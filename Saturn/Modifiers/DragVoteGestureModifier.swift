//
//  DragVoteGestureModifier.swift
//  Saturn
//
//  Created by James Eunson on 24/3/2023.
//

import Foundation
import SwiftUI

struct DragVoteGestureModifier: ViewModifier {
    @Binding var dragOffset: CGFloat
    let onTapVote: ((HTMLAPIVoteDirection) -> Void)?
    
    func body(content: Content) -> some View {
        content.gesture(DragGesture(minimumDistance: 30, coordinateSpace: .local)
            .onChanged({ value in
                withAnimation {
                    let width = abs(value.translation.width)
                    if width < (UIScreen.main.bounds.size.width / 4) {
                        dragOffset = value.translation.width
                    }
                    if width > 80 {
                        let impactMed = UIImpactFeedbackGenerator(style: .medium)
                        impactMed.impactOccurred()
                    }
                }
            }).onEnded({ value in
                if value.translation.width > 80 {
                    onTapVote?(.upvote)
                }
                if value.translation.width < -80 {
                    onTapVote?(.downvote)
                }
                if abs(value.translation.width) > 0 {
                    withAnimation {
                        dragOffset = 0
                    }
                }
        }))
    }
}
