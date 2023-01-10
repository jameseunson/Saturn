//
//  StoryDetailView.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 8/1/2023.
//

import Foundation
import SwiftUI

struct StoryDetailView: View {
    let story: Story
    @StateObject var viewModel: StoryDetailViewModel
    @State private var isShowingSafariView = false
    
    let formatter = RelativeDateTimeFormatter()
    @State var isShareVisible: Bool = false
    
    var body: some View {
        VStack {
            List {
                Section {
                    if viewModel.comments.count == 0 {
                        ListLoadingView()
                    } else {
                        ForEach(viewModel.comments) { comment in
                            VStack(alignment: .leading) {
                                HStack {
                                    Text(comment.by)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(formatter.localizedString(for: comment.comment.time, relativeTo: Date()))
                                        .font(.caption)
                                }
                                Divider()
                                Text(comment.comment.text)
                            }
                        }
                    }
                } header: {
                    StoryRowView(story: story)
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
                        .onTapGesture {
                            isShowingSafariView = true
                        }
                }
            }
            .listStyle(.plain)
            .onAppear {
                viewModel.activate()
            }
            .refreshable {
                await viewModel.refreshComments()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    isShareVisible = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $isShareVisible, content: {
            if let url = story.url {
                let sheet = ActivityViewController(itemsToShare: [url])
                    .ignoresSafeArea()
                if #available(iOS 16, *) {
                    sheet.presentationDetents([.medium])
                } else {
                    sheet
                }
            }
        })
        .sheet(isPresented: $isShowingSafariView) {
            if let url = story.url {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
    }
}
