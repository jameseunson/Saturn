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
    @State private var isLoggedIn = false
    
    let apiManager = APIManager()
    
    let formatter = RelativeDateTimeFormatter()
    let story: StoryRowViewModel
    let onTapArticleLink: ((URL) -> Void)?
    let onTapUser: ((String) -> Void)?
    let onTapVote: ((HTMLAPIVoteDirection) -> Void)?
    let onTapSheet: ((StoryRowViewModel) -> Void)?
    let context: StoryRowViewContext
    
    init(story: StoryRowViewModel,
         onTapArticleLink: ((URL) -> Void)? = nil,
         onTapUser: ((String) -> Void)? = nil,
         onTapVote: ((HTMLAPIVoteDirection) -> Void)? = nil,
         onTapSheet: ((StoryRowViewModel) -> Void)? = nil,
         context: StoryRowViewContext = .storiesList,
         keychainWrapper: SaturnKeychainWrapping = SaturnKeychainWrapper.shared) {
        self.story = story
        self.onTapArticleLink = onTapArticleLink
        self.onTapUser = onTapUser
        self.context = context
        self.onTapVote = onTapVote
        self.onTapSheet = onTapSheet
        _isLoggedIn = .init(initialValue: keychainWrapper.isLoggedIn)
    }
    
    var body: some View {
        ZStack {
            if isLoggedIn,
               let vote = story.vote,
            abs(dragOffset) > 0 {
                VoteBackdropView(dragOffset: $dragOffset,
                                 vote: vote)
                .transition(.identity)
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
                if isLoggedIn,
                   context != .user {
                    HStack(alignment: .top) {
                        Image(systemName: "ellipsis")
                            .contentShape(Rectangle())
                            .font(.body)
                            .foregroundColor(.gray)
                            .frame(width: 30, height: 30)
                            .onTapGesture {
                                let impactMed = UIImpactFeedbackGenerator(style: .medium)
                                impactMed.impactOccurred()
                                
                                onTapSheet?(story)
                            }
                        Spacer()
                        if let vote = story.vote {
                            if vote.directions.contains(.upvote) {
                                Button {
                                    let impactMed = UIImpactFeedbackGenerator(style: .medium)
                                    impactMed.impactOccurred()
                                    onTapVote?(.upvote)
                                } label: {
                                    Text(Image(systemName: "arrow.up"))
                                        .font(.body)
                                        .foregroundColor(vote.state == .upvote ? .accentColor : .gray)
                                }
                            }
                            if vote.directions.contains(.downvote) {
                                Button {
                                    let impactMed = UIImpactFeedbackGenerator(style: .medium)
                                    impactMed.impactOccurred()
                                    onTapVote?(.downvote)
                                } label: {
                                    Text(Image(systemName: "arrow.down"))
                                        .font(.body)
                                        .foregroundColor(vote.state == .downvote ? .accentColor : .gray)
                                }
                            }
                        }
                    }
                    .frame(minHeight: 33)
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
        .if(isLoggedIn, transform: { view in
            view.modifier(DragVoteGestureModifier(dragOffset: $dragOffset,
                                                  onTapVote: onTapVote,
                                                  directionsEnabled: story.vote?.directions ?? []))
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

struct StoryRowView_Previews: PreviewProvider {
    static var previews: some View {
        StoryRowView(story: StoryRowViewModel(story: Story.fakeStory()!, vote: HTMLAPIVote.fakeVote()),
                     keychainWrapper: SaturnKeychainWrapper(loginOverride: true))
    }
}

enum StoryRowViewContext {
    case storiesList
    case storyDetail
    case user
}
