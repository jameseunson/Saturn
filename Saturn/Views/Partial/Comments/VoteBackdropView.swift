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
    let vote: HTMLAPIVote?
    
    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                if let vote,
                   vote.directions.contains(.upvote) {
                    Color.accentColor
                }
                Image(systemName: vote?.directions.contains(.upvote) ?? false ? "arrow.up" : "xmark")
                    .foregroundColor(.white)
                    .font(.title)
                    .padding(.trailing, 50)
                    .opacity(Double(abs(dragOffset)) / 100.0)
            }
            Color(UIColor.systemBackground)
            ZStack {
                if let vote,
                   vote.directions.contains(.downvote) {
                    Color.blue
                }
                Image(systemName: vote?.directions.contains(.downvote) ?? false ? "arrow.down" : "xmark")
                    .foregroundColor(.white)
                    .font(.title)
                    .padding(.leading, 50)
                    .opacity(Double(abs(dragOffset)) / 100.0)
            }
        }
    }
}
