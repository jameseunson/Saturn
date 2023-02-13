//
//  SpinnerView.swift
//  Saturn
//
//  Created by James Eunson on 26/1/2023.
//

import Foundation
import SwiftUI

struct SpinnerConfiguration {
    var width: CGFloat = 25
    var height: CGFloat = 25
    var speed: TimeInterval = 0.5
    var lineWidth: Double = 5.0
}

struct SpinnerView: View {
    var configuration: SpinnerConfiguration = SpinnerConfiguration()
    @State var isAnimating = false

    var body: some View {
        Circle()
            .trim(from: 0.0, to: 0.6)
            .stroke(Color.accentColor, lineWidth: configuration.lineWidth)
            .frame(width: configuration.width, height: configuration.height)
            .rotationEffect(Angle(degrees: self.isAnimating ? 360 : 0.0))
            .animation(.linear(duration: configuration.speed).repeatForever(autoreverses: false), value: isAnimating)
            .padding()
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.isAnimating = true
                }
            }
    }
}

