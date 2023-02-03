//
//  StoriesView.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 7/1/2023.
//

import SwiftUI

struct StoriesView: View {
    let type: StoryListType
    
    @ObservedObject var interactor: StoriesInteractor
    @State var isSettingsVisible: Bool = false
    @State var isSearchVisible: Bool = false
    @State var selectedShareItem: URL?
    @State var selectedUser: String?
    @State var displayingSafariURL: URL?
    
    init(type: StoryListType) {
        self.type = type
        self.interactor = StoriesInteractor(type: type)
    }
    
    var body: some View {
        ZStack {
            switch interactor.loadingState {
            case .loaded, .loadingMore:
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(interactor.stories) { story in
                            Divider()
                                .padding(.bottom, 10)
                                .padding(.leading, 15)
                            NavigationLink(value: story) {
                                StoryRowView(story: StoryRowViewModel(story: story),
                                             onTapArticleLink: { url in self.displayingSafariURL = url },
                                             onTapUser: { user in self.selectedUser = user },
                                             showsTextPreview: true)
                                    .onAppear {
                                        if story == interactor.stories.last {
                                            interactor.loadNextPage()
                                        }
                                    }
                                    .contextMenu {
                                        Button(action: { selectedShareItem = story.url }, label:
                                        {
                                            Label("Share", systemImage: "square.and.arrow.up")
                                        })
                                        Button(action: { selectedUser = story.by }, label:
                                        {
                                            Label(story.by, systemImage: "person.circle")
                                        })
                                    }
                                    .padding([.leading, .trailing], 15)
                                    .padding(.bottom, 25)
                            }
                        }
                        ListLoadingView()
                    }
                }
                .navigationDestination(for: Story.self) { story in
                    let interactor = StoryDetailInteractor(story: story)
                    StoryDetailView(interactor: interactor)
                        .navigationTitle(story.title)
                }
                .refreshable {
                    await interactor.refreshStories()
                }
                
                if isSearchVisible {
                    SearchNavigationView(isSearchVisible: $isSearchVisible)
                }
                
            case .failed, .initialLoad:
                LoadingView(isFailed: isFailedBinding())
            }
        }
        .toolbar {
            if !isSearchVisible {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button {
                        isSettingsVisible = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
                if AppRemoteConfig.instance.isSearchEnabled() {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Button {
                            isSearchVisible = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                    }
                }
            }
        }
        .navigationDestination(isPresented: createBoolBinding(from: $selectedUser)) {
            if let selectedUser {
                UserView(interactor: UserInteractor(username: selectedUser))
                    .navigationTitle(selectedUser)
            } else {
                EmptyView()
            }
        }
        .sheet(isPresented: $isSettingsVisible, content: {
            SettingsNavigationView(isSettingsVisible: $isSettingsVisible)
        })
        .sheet(isPresented: createBoolBinding(from: $selectedShareItem), content: {
            if let url = selectedShareItem {
                let sheet = ActivityViewController(itemsToShare: [url])
                    .ignoresSafeArea()
                sheet.presentationDetents([.medium])
            }
        })
        .sheet(isPresented: createBoolBinding(from: $displayingSafariURL)) {
            if let displayingSafariURL {
                SafariView(url: displayingSafariURL)
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            interactor.activate()
        }
    }
    
    // MARK: - Bindings
    func isFailedBinding() -> Binding<Bool> {
        Binding {
            interactor.loadingState == .failed
        } set: { value in
            if !value {
                interactor.loadingState = .initialLoad
                interactor.loadNextPage()
            }
        }
    }
}

struct StoriesView_Previews: PreviewProvider {
    static var previews: some View {
        StoriesView(type: .top)
            .environmentObject(StoriesInteractor(type: .top))
    }
}
