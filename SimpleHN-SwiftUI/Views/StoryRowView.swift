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
    let story: Story
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading) {
                Text(story.title)
                    .font(.title3)
                    .foregroundColor(.black)
                HStack {
                    if let url = story.url,
                    let host = url.host {
                        Text(host)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Text(story.by)
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(formatter.localizedString(for: story.time, relativeTo: Date()))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                HStack {
                    Text(String(story.score))
                        .font(.caption)
                        .foregroundColor(Color.accentColor)
                    Image(systemName: "arrow.up.square.fill")
                        .renderingMode(.template)
                        .foregroundColor(Color.accentColor)
                        .padding(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0))
                }
                if let descendants = story.descendants {
                    HStack {
                        Text(String(descendants))
                            .font(.caption)
                            .foregroundColor(Color.gray)
                        Image(systemName: "text.bubble.fill")
                            .renderingMode(.template)
                            .foregroundColor(Color(uiColor: UIColor.systemGray3))
                    }
                }
            }
            .padding(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 0))
        }
    }
}
