//
//  UserView.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 11/1/2023.
//

import Foundation
import SwiftUI

enum UserSegment: Int {
    case comments
    case submissions
}

enum UserItemViewModel: Identifiable {
    var id: ObjectIdentifier {
        switch self {
        case let .comment(comment):
            return comment.id
        case let .story(story):
            return story.id
        }
    }
    
    case comment(CommentViewModel)
    case story(StoryRowViewModel)
}

struct UserView: View {
    @StateObject var interactor: UserInteractor
    @State var user: UserViewModel?
    
    @State var displayingSafariURL: URL?
    @State var items: [UserItemViewModel] = []
    
    var body: some View {
        if let user {
            ScrollView {
                UserHeaderView(user: user, displayingSafariURL: $displayingSafariURL)
                    .padding([.leading, .trailing])

                Divider()
                
                ForEach(items) { item in
                    switch item {
                    case let .comment(comment):
                        CommentView(expanded: .constant(.expanded), comment: comment) { comment in
                            
                        } onTapOptions: { comment in
                            
                        } onToggleExpanded: { comment, expanded in
                            
                        }
                        .padding([.trailing, .leading, .bottom])

                    case let .story(story):
                        StoryRowView(story: story)
                            .padding([.trailing, .leading, .bottom])
                    }
                }
                ListLoadingView()
            }
            .sheet(isPresented: displayingSafariViewBinding()) {
                if let displayingSafariURL {
                    SafariView(url: displayingSafariURL)
                        .ignoresSafeArea()
                }
            }
            .onReceive(interactor.$items) { output in
                self.items = output
            }

        } else {
            LoadingView()
            .onAppear {
                interactor.activate()
            }
            .onReceive(interactor.$user) { output in
                if let output {
                    self.user = UserViewModel(user: output)
                }
            }
            .onReceive(interactor.$items) { output in
                self.items = output
            }
        }
    }
    
    func displayingSafariViewBinding() -> Binding<Bool> {
        Binding {
            displayingSafariURL != nil
        } set: { value in
            if !value { displayingSafariURL = nil }
        }
    }
}
