//
//  StoryRowView.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 9/1/2023.
//

import Foundation
import SwiftUI

struct StoryRowView: View {
    let formatter = RelativeDateTimeFormatter()
    let story: StoryRowViewModel
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(story.title)
                    .font(.title3)
                    .foregroundColor(Color.primary)
                Text(story.subtitle)
                    .font(.callout)
                    .foregroundColor(.gray)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                HStack {
                    Text(String(story.score))
                        .font(.callout)
                        .foregroundColor(Color.accentColor)
                    Image(systemName: "arrow.up.square.fill")
                        .renderingMode(.template)
                        .foregroundColor(Color.accentColor)
                        .padding(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0))
                }
                HStack {
                    Text(String(story.comments))
                        .font(.callout)
                        .foregroundColor(Color.gray)
                    Image(systemName: "text.bubble.fill")
                        .renderingMode(.template)
                        .foregroundColor(Color(uiColor: UIColor.systemGray3))
                }
            }
            .padding(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 0))
        }
    }
}
