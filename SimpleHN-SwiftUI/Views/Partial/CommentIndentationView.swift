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
//                .foregroundColor(.gray)
                .padding(.trailing, 5)
                .foregroundColor(Color.random)
        } else {
            EmptyView()
        }
    }
}
