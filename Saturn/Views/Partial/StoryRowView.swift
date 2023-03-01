//
//  StoryRowView.swift
//  Saturn
//
//  Created by James Eunson on 9/1/2023.
//

import Foundation
import SwiftUI

struct StoryRowView: View {
    @State var image: Image?
    
    let formatter = RelativeDateTimeFormatter()
    let story: StoryRowViewModel
    let onTapArticleLink: ((URL) -> Void)?
    let onTapUser: ((String) -> Void)?
    let showsTextPreview: Bool
    
    init(story: StoryRowViewModel, onTapArticleLink: ((URL) -> Void)? = nil, onTapUser: ((String) -> Void)? = nil, showsTextPreview: Bool = false) {
        self.story = story
        self.onTapArticleLink = onTapArticleLink
        self.onTapUser = onTapUser
        self.showsTextPreview = showsTextPreview
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(story.title)
                        .font(.title3)
                        .foregroundColor(Color.primary)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 0) {
                        Button {
                            if let onTapUser {
                                onTapUser(story.author)
                            }
                        } label: {
                            Text(story.author)
                                .font(.callout)
                                .foregroundColor(.gray)
                                .fontWeight(.medium)
                                .multilineTextAlignment(.leading)
                        }
                        .contentShape(Rectangle())
                        
                        Text(" · " + story.timeAgo)
                            .font(.callout)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.leading)
                    }
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
            if let url = story.url {
                HStack {
                    HStack {
                        if let image {
                            ZStack {
                                Rectangle().foregroundColor(.white)
                                image
                                    .resizable()
                                    .frame(width: 33, height: 33)
                                    .aspectRatio(contentMode: .fit)
                            }
                        } else {
                            Image(systemName: "link")
                                .foregroundColor(.gray)
                                .font(.title3)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .background {
                        Rectangle()
                            .foregroundColor(Color(UIColor.systemGray4))
                    }
                    .cornerRadius(10, corners: [.topLeft, .bottomLeft])
                    
                    Text(url.absoluteString)
                        .padding(.leading, 10)
                        .lineLimit(1)
                        .foregroundColor(.gray)
                        .font(.callout)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .padding(.trailing, 10)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .foregroundColor( Color(UIColor.systemGray6) )
                }
                .onTapGesture {
                    if let onTapArticleLink {
                        onTapArticleLink(url)
                    }
                }
                
            } else if let text = story.text,
                      showsTextPreview {
                Spacer().frame(height: 12)
                Text(NSMutableAttributedString(text).string)
                    .lineLimit(2)
                    .font(.callout)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.leading)
            }
        }
        .onAppear {
            Task {
                let storyImage = await StoryImageLoader.default.get(for: story)
                withAnimation {
                    image = storyImage
                }
            }
        }
    }
}
