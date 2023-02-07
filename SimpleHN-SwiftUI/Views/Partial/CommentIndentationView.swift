//
//  CommentIndentationView.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 31/1/2023.
//

import Foundation
import SwiftUI

struct CommentIndentationView: View {
    let comment: CommentViewModel
    
    var body: some View {
        if comment.indendation > 0 {
            Spacer()
                .frame(width: CGFloat(comment.indendation) * 20)
            
            RoundedRectangle(cornerSize: .init(width: 1, height: 1))
                .frame(width: 2)
                .padding(.trailing, 5)
//                .foregroundColor(Color.random)
                .foregroundColor(color())
        } else {
            EmptyView()
        }
        
//        Color.init(hue: Double(Color.accentColor.hsbComponents?.hue ?? 1.0),
//                                    saturation: 1.0 - (0.2 * Double(comment.indendation - 1)),
//                                    brightness: 1)
    }
    
    func color() -> Color {
        let color = Settings.default.indentationColor()
        switch color {
        case .random:
            return Color.random
        case .none:
            return Color.gray
        case .some(.default):
            return Color.gray
        case .some(.hnOrange):
            return Color.accentColor
        case .some(.userSelected(color: let color)):
            if let color {
                return color
            } else {
                return Color.gray
            }
        case .some(.randomPost):
            return Color.random
        }
    }
}
