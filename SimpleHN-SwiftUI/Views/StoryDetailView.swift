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
    @EnvironmentObject var viewModel: StoryDetailViewModel
    
    @State private var isShowingSafariView = false
    
    var body: some View {
        VStack {
            List {
                Section {
                    if case let .loaded(comments) = viewModel.comments {
                        
                    } else {
                        ProgressView()
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
            
            Spacer()
        }
        .sheet(isPresented: $isShowingSafariView) {
            if let url = story.url {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
    }
}
