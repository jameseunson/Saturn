//
//  VoteBackdropView.swift
//  Saturn
//
//  Created by James Eunson on 24/3/2023.
//

import Foundation
import SwiftUI

struct VoteBackdropView: View {
    @Binding var dragOffset: CGFloat
    
    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                Color.accentColor
                Image(systemName: "arrow.up")
                    .foregroundColor(.white)
                    .font(.title)
                    .padding(.trailing, 50)
                    .opacity(Double(abs(dragOffset)) / 100.0)
            }
            Color(UIColor.systemBackground)
            ZStack {
                Color.blue
                Image(systemName: "arrow.down")
                    .foregroundColor(.white)
                    .font(.title)
                    .padding(.leading, 50)
                    .opacity(Double(abs(dragOffset)) / 100.0)
            }
        }
    }
}
