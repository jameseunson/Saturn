//
//  StoryRowView.swift
//  Saturn
//
//  Created by James Eunson on 9/1/2023.
//

import Foundation
import SwiftUI
import Factory
import SwipeActions

struct StoryRowView: View {
    @Injected(\.keychainWrapper) private var keychainWrapper
    @Injected(\.apiManager) private var apiManager
    
    @Binding var image: Image?
    @State private var isLoggedIn = false
    
    let formatter = RelativeDateTimeFormatter()
    let story: StoryRowViewModel
    let onTapArticleLink: ((URL) -> Void)?
    let onTapUser: ((String) -> Void)?
    let onTapVote: ((HTMLAPIVoteDirection) -> Void)?
    let onTapSheet: ((StoryRowViewModel) -> Void)?
    let context: StoryRowViewContext
    
    init(story: StoryRowViewModel,
         image: Binding<Image?>,
         onTapArticleLink: ((URL) -> Void)? = nil,
         onTapUser: ((String) -> Void)? = nil,
         onTapVote: ((HTMLAPIVoteDirection) -> Void)? = nil,
         onTapSheet: ((StoryRowViewModel) -> Void)? = nil,
         context: StoryRowViewContext = .storiesList) {
        self.story = story
        self.onTapArticleLink = onTapArticleLink
        self.onTapUser = onTapUser
        self.context = context
        self.onTapVote = onTapVote
        self.onTapSheet = onTapSheet
        _image = image
        _isLoggedIn = .init(initialValue: keychainWrapper.isLoggedIn)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SwipeView {
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
                                    .opacity(0.6)
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
                    .padding(.leading, 15)
                    if let url = story.url {
                        StoryRowURLView(image: $image,
                                        url: url,
                                        onTapArticleLink: onTapArticleLink,
                                        context: context)
                        .padding(.leading, 15)
                        
                    } else if let text = story.text,
                              context == .storiesList {
                        Spacer().frame(height: 12)
                        Text(NSMutableAttributedString(text).string)
                            .lineLimit(2)
                            .font(.callout)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.leading)
                            .padding(.leading, 15)
                    }
                    if isLoggedIn,
                       context != .user {
                        StoryLoggedInOptionsView(story: story,
                                                 onTapVote: onTapVote,
                                                 onTapSheet: onTapSheet)
                    }
                }
                .padding(.bottom, keychainWrapper.isLoggedIn ? 0 : 15)
                .padding(.trailing, 15)
                .padding(.top, context == .storiesList ? 10 : 0)
                .drawingGroup()
                
            } leadingActions: { context in
                if isLoggedIn,
                   self.context != .user,
                   let vote = story.vote,
                   vote.directions.contains(.upvote) {
                    SwipeAction.action(direction: .upvote, onTapVote: onTapVote, context: context)
                }
                
            } trailingActions: { context in
                if isLoggedIn,
                   self.context != .user,
                   let vote = story.vote,
                   vote.directions.contains(.downvote) {
                    SwipeAction.action(direction: .downvote, onTapVote: onTapVote, context: context)
                }
            }
            .swipeDefaults()
            
            if context != .user {
                Divider()
                    .padding(.leading, context == .storyDetail ? 0 : 15)
                    .padding([.bottom, .top], 0)
            }
        }
        .onReceive(keychainWrapper.isLoggedInSubject) { output in
            isLoggedIn = output
        }
        .contentShape(Rectangle())
    }
}

struct StoryRowView_Previews: PreviewProvider {
    static var previews: some View {
        let _ = Container.shared.keychainWrapper.register { SaturnKeychainWrapper(loginOverride: true) }
        StoryRowView(story: StoryRowViewModel(story: Story.fakeStory()!, vote: HTMLAPIVote.fakeVote()), image: .constant(nil))
    }
}

enum StoryRowViewContext {
    case storiesList
    case storyDetail
    case user
}
