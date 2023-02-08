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
                .foregroundColor(color())
                .brightness((0.2 * Double(comment.indendation - 1)))
            
        } else {
            EmptyView()
        }
    }
    
    func color() -> Color {
        let color = Settings.default.indentationColor()
        switch color {
        case .random:
            return Color.random
        case .none:
            return Color(uiColor: UIColor.systemGray3)
        case .some(.default):
            return Color(uiColor: UIColor.systemGray3)
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
