//
//  CommentView.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 11/1/2023.
//

import Foundation
import SwiftUI

struct CommentView: View {
    let formatter = RelativeDateTimeFormatter()
    let comment: CommentViewModel
    
    let onTapUser: (CommentViewModel) -> Void
    let onTapOptions: (CommentViewModel) -> Void
    let onTapHeader: (CommentViewModel) -> Void
    
    var body: some View {
        HStack {
            Spacer()
                .frame(width: CGFloat(comment.indendation) * 20)
            VStack(alignment: .leading) {
                HStack {
                    Text(comment.by)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(Color.accentColor)
                        .onTapGesture {
                            onTapUser(comment)
                        }
                    Spacer()
                    Text(formatter.localizedString(for: comment.comment.time, relativeTo: Date()))
                        .font(.body)
                        .foregroundColor(.gray)
                    Button {
                        onTapOptions(comment)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.body)
                            .foregroundColor(.gray)
                    }

                }
                .allowsHitTesting(true)
                .onTapGesture {
                    onTapHeader(comment)
                }
                Divider()
                Text(comment.comment.text)
                    .font(.body)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .listRowSeparator(.hidden)
    }
}
