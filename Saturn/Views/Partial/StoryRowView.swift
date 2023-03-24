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
    @State private var dragOffset: CGFloat = 0
    
    let apiManager = APIManager()
    
    let formatter = RelativeDateTimeFormatter()
    let story: StoryRowViewModel
    let onTapArticleLink: ((URL) -> Void)?
    let onTapUser: ((String) -> Void)?
    let onTapVote: ((HTMLAPICommentVoteDirection) -> Void)?
    let context: StoryRowViewContext
    
    init(story: StoryRowViewModel,
         onTapArticleLink: ((URL) -> Void)? = nil,
         onTapUser: ((String) -> Void)? = nil,
         onTapVote: ((HTMLAPICommentVoteDirection) -> Void)? = nil,
         context: StoryRowViewContext = .storiesList) {
        self.story = story
        self.onTapArticleLink = onTapArticleLink
        self.onTapUser = onTapUser
        self.context = context
        self.onTapVote = onTapVote
    }
    
    var body: some View {
        ZStack {
            if SaturnKeychainWrapper.shared.isLoggedIn,
            abs(dragOffset) > 0 {
                VoteBackdropView(dragOffset: $dragOffset)
            }
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
                    StoryRowURLView(image: $image,
                                    url: url,
                                    onTapArticleLink: onTapArticleLink)
                    
                } else if let text = story.text,
                          context == .storiesList {
                    Spacer().frame(height: 12)
                    Text(NSMutableAttributedString(text).string)
                        .lineLimit(2)
                        .font(.callout)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                }
            }
            .offset(.init(width: dragOffset, height: 0))
            .background {
                if context == .user {
                    Color(UIColor.systemGray6)
                        .edgesIgnoringSafeArea(.all)
                        .offset(.init(width: dragOffset, height: 0))
                } else {
                    Color(UIColor.systemBackground)
                        .edgesIgnoringSafeArea(.all)
                        .offset(.init(width: dragOffset, height: 0))
                }
            }
            .padding([.leading, .trailing], 15)
        }
        .if(SaturnKeychainWrapper.shared.isLoggedIn, transform: { view in
            view.modifier(DragVoteGestureModifier(dragOffset: $dragOffset, onTapVote: onTapVote))
        })
        .onAppear {
            Task { @MainActor in
                let storyImage = try? await apiManager.getImage(for: story)
                withAnimation {
                    image = storyImage
                }
            }
        }
    }
}

struct StoryRowURLView: View {
    @Binding var image: Image?
    let url: URL
    let onTapArticleLink: ((URL) -> Void)?
    
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
    }
}

struct StoryRowView_Previews: PreviewProvider {
    static var previews: some View {
        StoryRowView(story: StoryRowViewModel(story: Story.fakeStory()!))
    }
}

enum StoryRowViewContext {
    case storiesList
    case storyDetail
    case user
}
