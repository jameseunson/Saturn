//
//  RootView.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 16/1/2023.
//

import Foundation
import SwiftUI

struct RootView: View {
    @StateObject var interactor = RootInteractor()
    
    var body: some View {
        TabView {
            NavigationStack {
                StoriesView(type: .top)
                    .navigationTitle("Top")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Top", systemImage: "list.dash")
            }
            NavigationStack {
                StoriesView(type: .new)
                    .navigationTitle("New")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("New", systemImage: "chart.line.uptrend.xyaxis")
            }
            NavigationStack {
                StoriesView(type: .show)
                    .navigationTitle("Show")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Show", systemImage: "binoculars")
            }
            NavigationStack {
                StoriesView(type: .ask)
                    .navigationTitle("Ask")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Ask", systemImage: "text.bubble")
            }
        }
        .onAppear {
            interactor.activate()
        }
    }
}
