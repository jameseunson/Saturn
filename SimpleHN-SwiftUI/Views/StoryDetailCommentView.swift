//
//  StoryDetailItemView.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 20/1/2023.
//

import Foundation
import SwiftUI

struct StoryDetailCommentView: View {
    @StateObject var interactor: StoryDetailCommentInteractor
    
    @State var selectedShareItem: StoryDetailShareItem?
    @State var selectedUser: String?
    @State var displayingInternalStoryId: Int?
    @State var selectedComment: CommentViewModel?
    
    @State var displayFullComments = false
    
    var body: some View {
        if let story = interactor.story {
            ZStack {
                ScrollViewReader { reader in
                    ScrollView {
                        StoryRowView(story: StoryRowViewModel(story: story))
                            .padding(EdgeInsets(top: 0, leading: 10, bottom: 20, trailing: 10))
                        
                        Divider()
                        
                        ForEach(interactor.comments) { comment in
                            CommentView(expanded: .constant(.expanded), comment: comment) { comment in
                                selectedComment = comment
                                
                            } onTapUser: { user in
                                selectedUser = user
                                
                            } onTapStoryId: { storyId in
                                self.displayingInternalStoryId = storyId
                            }
                            .id(comment.id)
                            .padding(10)
                        }
                    }
                    .onAppear {
                        // TODO: Does not work, fix
                        if let focusedCommentViewModel = interactor.focusedCommentViewModel {
                            withAnimation {
                                reader.scrollTo(focusedCommentViewModel.id)
                            }
                        }
                    }
                }
                .modifier(CommentNavigationModifier(selectedShareItem: $selectedShareItem,
                                                    selectedUser: $selectedUser,
                                                    displayingInternalStoryId: $displayingInternalStoryId,
                                                    selectedComment: $selectedComment))
                
                ViewAllCommentsButton(displayFullComments: $displayFullComments)
            }
            .navigationDestination(isPresented: $displayFullComments) {
                if let story = interactor.story {
                    StoryDetailView(interactor: StoryDetailInteractor(storyId: story.id))
                } else {
                    EmptyView()
                }
            }
            
        } else {
            LoadingView()
                .onAppear {
                    interactor.activate()
                }
        }
    }
}

struct StoryDetailCommentView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            #if DEBUG
            StoryDetailCommentView(interactor: StoryDetailCommentInteractor(focusedComment: CommentViewModel.fakeComment()))
                .navigationTitle("Story")
                .navigationBarTitleDisplayMode(.inline)
            #else
            EmptyView()
            #endif
        }
    }
}

struct ViewAllCommentsButton: View {
    @Binding var displayFullComments: Bool
    
    var body: some View {
        VStack {
            Spacer()
            Button {
                displayFullComments = true
            } label: {
                HStack {
                    Text("View all comments")
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white)
                }
                .padding()
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .foregroundColor(.primary)
            .background {
                Rectangle()
                    .cornerRadius(8)
                    .foregroundColor(Color.accentColor)
            }
        }
        .padding()
    }
}
