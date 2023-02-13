//
//  AnimatingCellHeight.swift
//  Saturn
//
//  Created by James Eunson on 9/2/2023.
//

import Foundation
import SwiftUI

struct AnimatingCellHeight: ViewModifier, Animatable {
    var height: CGFloat = 0
    
    private var target: CGFloat
    private var onEnded: () -> ()

    init(height: CGFloat, onEnded: @escaping () -> () = {}) {
        self.target = height
        self.height = height
        self.onEnded = onEnded
    }

    var animatableData: CGFloat {
        get { height }
        set {
            height = newValue
            if newValue == target {
                onEnded()
            }
        }
    }

    func body(content: Content) -> some View {
        content.frame(height: height)
    }
}
