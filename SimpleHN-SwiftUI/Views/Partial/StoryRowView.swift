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
    let onTapArticleLink: ((URL) -> Void)?
    let showsTextPreview: Bool
    
    init(story: StoryRowViewModel, onTapArticleLink: ((URL) -> Void)? = nil, showsTextPreview: Bool = false) {
        self.story = story
        self.onTapArticleLink = onTapArticleLink
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
                    Text(story.subtitle)
                        .font(.callout)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
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
                        AsyncImage(url: story.imageURL) { image in
                            ZStack {
                                Color.white
                                image.resizable()
                                    .padding(4)
                            }
                        } placeholder: {
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
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {

    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
