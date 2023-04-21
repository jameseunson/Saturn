//
//  StoryRowURLView.swift
//  Saturn
//
//  Created by James Eunson on 27/3/2023.
//

import Foundation
import SwiftUI

struct StoryRowURLView: View {
    @Binding var image: Image?
    let url: URL
    let onTapArticleLink: ((URL) -> Void)?
    let context: StoryRowViewContext
    
    var body: some View {
        HStack {
            HStack {
                if let image {
                    ZStack {
                        Rectangle().foregroundColor(.white)
                        image
                            .resizable()
                            .frame(width: 33, height: 33)
                            .aspectRatio(contentMode: .fit)
                        
                        Rectangle()
                            .foregroundColor(.clear)
                            .cornerRadius(10, corners: [.topLeft, .bottomLeft])
                            .border(Color(UIColor.systemGray6), width: 1)
                    }
                    
                } else {
                    Image(systemName: "link")
                        .foregroundColor(.gray)
                        .font(.title3)
                }
            }
            .animation(.linear, value: image)
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
            switch context {
            case .storiesList, .storyDetail:
                RoundedRectangle(cornerRadius: 8)
                    .foregroundColor( Color(UIColor.systemGray6) )
            case .user:
                RoundedRectangle(cornerRadius: 8)
                    .foregroundColor( Color(UIColor.systemGray5) )
            }
        }
        .onTapGesture {
            if let onTapArticleLink {
                onTapArticleLink(url)
            }
        }
    }
}

struct StoryRowURLView_Preview: PreviewProvider {
    static var previews: some View {
        StoryRowView(story: StoryRowViewModel(story: Story.fakeStory()!), image: .constant(Image("AppIcon")))
    }
}
