//
//  UserView.swift
//  Saturn
//
//  Created by James Eunson on 11/1/2023.
//

import Foundation
import SwiftUI

struct UserView: View {
    @StateObject var interactor: UserInteractor
    @State var user: UserViewModel?
    
    @State var contexts: [Int: UserCommentContextType] = [:]
    
    /// Infinite scroll
    @State private var readyToLoadMore = false
    @State private var itemsRemainingToLoad = false
    
    /// Navigation
    @State var displayingSafariURL: URL?
    @State var selectedCommentToShare: CommentViewModel?
    @State var selectedStoryToView: StoryRowViewModel?
    @State var selectedCommentToView: CommentViewModel?
    @State var displayingInternalStoryId: Int?
    @State var favIcons: [String: Image] = [:]
    
    /// NSUserActivity - handoff
    static let userActivity = "au.jameseunson.Saturn.view-user"
    
    var body: some View {
        ScrollViewReader { reader in
            InfiniteScrollView(loader: interactor,
                               readyToLoadMore: $readyToLoadMore,
                               itemsRemainingToLoad: $itemsRemainingToLoad) {
                
                if let user {
                    UserHeaderView(user: user, displayingSafariURL: $displayingSafariURL) { user in
                        // TODO:
                        
                    } onTapStoryId: { storyId in
                        displayingInternalStoryId = storyId
                        
                    } onTapURL: { url in
                        displayingSafariURL = url
                    }
                    .id("top")
                    .padding()
                    
                    Divider()
                }

                if case .loading = interactor.items {
                    ListLoadingView()
                    
                } else if case let .loaded(items) = interactor.items {
                    if items.count == 0 {
                        HStack {
                            Spacer()
                            Text("No submissions yet...")
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .frame(height: UIScreen.main.bounds.height - 250)
                        .listRowSeparator(.hidden)
                        
                    } else {
                        ForEach(items) { item in
                            switch item {
                            case let .comment(comment):
                                CommentContextView(comment: comment,
                                                   reader: reader,
                                                   selectedCommentToShare: $selectedCommentToShare,
                                                   selectedStoryToView: $selectedStoryToView,
                                                   selectedCommentToView: $selectedCommentToView,
                                                   contexts: $contexts,
                                                   displayingInternalStoryId: $displayingInternalStoryId,
                                                   displayingSafariURL: $displayingSafariURL,
                                                   favIcons: $favIcons)

                            case let .story(story):
                                StoryRowView(story: story,
                                             image: bindingForStoryImage(story: story),
                                             onTapArticleLink: { url in self.displayingSafariURL = url })
                                    .onTapGesture {
                                        selectedStoryToView = story
                                    }
                                    .padding([.top, .bottom], 10)
                            }
                            Divider()
                        }
                        if itemsRemainingToLoad {
                            ListLoadingView()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: createBoolBinding(from: $displayingSafariURL)) {
            if let displayingSafariURL {
                SafariView(url: displayingSafariURL)
                    .ignoresSafeArea()
            }
        }
        .sheet(isPresented: createBoolBinding(from: $selectedCommentToShare), content: {
            if let url = selectedCommentToShare?.comment.url {
                let sheet = ActivityViewController(itemsToShare: [url])
                    .ignoresSafeArea()
                sheet.presentationDetents([.medium])
            }
        })
        .onReceive(interactor.$readyToLoadMore, perform: { output in
            readyToLoadMore = output
        })
        .onReceive(interactor.$itemsRemainingToLoad, perform: { output in
            itemsRemainingToLoad = output
        })
        .onReceive(interactor.commentContexts, perform: { output in
            withAnimation {
                contexts = output
            }
        })
        .refreshable {
            await interactor.refreshUser()
        }
        .navigationDestination(isPresented: createBoolBinding(from: $selectedStoryToView)) {
            if let selectedStoryToView {
                StoryDetailView(interactor: StoryDetailInteractor(itemId: selectedStoryToView.id))
                    .navigationTitle(selectedStoryToView.title)
            } else {
                EmptyView()
            }
        }
        .navigationDestination(isPresented: createBoolBinding(from: $selectedCommentToView)) {
            if let selectedCommentToView,
               let container = contexts[selectedCommentToView.id],
               case let .loaded(thread) = container {
                StoryDetailView(interactor: StoryDetailInteractor(comment: selectedCommentToView, thread: thread))
                    .navigationTitle(thread.story?.title ?? "")
            } else {
                EmptyView()
            }
        }
        .navigationDestination(isPresented: createBoolBinding(from: $displayingInternalStoryId)) {
            if let displayingInternalStoryId {
                StoryDetailView(interactor: StoryDetailInteractor(itemId: displayingInternalStoryId))
            } else {
                EmptyView()
            }
        }
        .userActivity(UserView.userActivity) { activity in
            if let user = interactor.user,
               let url = URL(string: "https://news.ycombinator.com/user?id=\(user.id)") {
                activity.webpageURL = url
                activity.becomeCurrent()
            }
        }
        .onAppear {
            interactor.activate()
        }
        .onReceive(interactor.$user) { output in
            if let output {
                self.user = UserViewModel(user: output)
            }
        }
        .onReceive(interactor.$favIcons) { output in
            self.favIcons = output
        }
    }
    
    func bindingForStoryImage(story: StoryRowViewModel) -> Binding<Image?> {
        Binding { return interactor.favIcons[String(story.id)] } set: { _ in }
    }
}

struct CommentContextView: View {
    let comment: CommentViewModel
    let reader: ScrollViewProxy
    
    @Binding var selectedCommentToShare: CommentViewModel?
    @Binding var selectedStoryToView: StoryRowViewModel?
    @Binding var selectedCommentToView: CommentViewModel?
    @Binding var contexts: [Int: UserCommentContextType]
    @Binding var displayingInternalStoryId: Int?
    @Binding var displayingSafariURL: URL?
    @Binding var favIcons: [String: Image]
    
    var body: some View {
        VStack {
            CommentView(expanded: .constant(.expanded),
                        comment: comment,
                        displaysStory: true,
                        context: .user) { comment in
                selectedCommentToShare = comment
                
            } onTapUser: { _ in
                withAnimation {
                    reader.scrollTo("top")
                }
                
            } onToggleExpanded: { comment, expanded, commentOnScreen in
                if let context = contexts[comment.id],
                   case .loaded(_) = context {
                    selectedCommentToView = comment
                }
                
            } onTapStoryId: { storyId in
                displayingInternalStoryId = storyId
                
            } onTapURL: { url in
                self.displayingSafariURL = url
            }
            Button {
                if let context = contexts[comment.id],
                    case let .loaded(thread) = context,
                       let story = thread.story {
                    selectedStoryToView = StoryRowViewModel(story: story)
                }
            } label: {
                VStack(alignment: .leading) {
                    if let context = contexts[comment.id] {
                        if case let .loaded(thread) = context,
                           let story = thread.story {
                            StoryRowView(story: StoryRowViewModel(story: story),
                                         image: bindingForStoryImage(story: StoryRowViewModel(story: story)),
                                         onTapArticleLink: { url in self.displayingSafariURL = url },
                                         context: .user)
                                .padding([.top, .bottom], 10)
                        } else if case .failed = context {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                Text("Could not load context thread")
                                    .foregroundColor(.gray)
                                    .font(.body)
                            }
                            .padding()
                        }

                    } else {
                        ProgressView()
                            .padding()
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(UserContextStoryButtonStyle())
            .padding(10)
            .padding(.bottom, 20)
        }
    }
    
    func bindingForStoryImage(story: StoryRowViewModel) -> Binding<Image?> {
        Binding { return favIcons[String(story.id)] } set: { _ in }
    }
}

struct UserContextStoryButtonStyle: ButtonStyle {
    public func makeBody(configuration: StoriesListButtonStyle.Configuration) -> some View {
        configuration.label
            .background {
                if configuration.isPressed {
                    RoundedRectangle(cornerRadius: 8)
                        .foregroundColor( Color(uiColor: UIColor.systemGray3) )
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .foregroundColor( Color(UIColor.systemGray6) )
                }
            }
    }
}
