//
//  RootView.swift
//  Saturn
//
//  Created by James Eunson on 16/1/2023.
//

import Foundation
import SwiftUI
import AlertToast
import Factory

struct RootView: View {
    @Injected(\.networkConnectivityManager) private var networkConnectivityManager
    @Injected(\.keychainWrapper) private var keychainWrapper
    @Injected(\.appRemoteConfig) private var appRemoteConfig
    
    @StateObject var interactor = RootInteractor()
    
    @State var titleForUser = "User"
    @State var showConnectionAlert: Bool = false
    
    var body: some View {
        TabView {
            NavigationStack {
                StoriesListView(interactor: StoriesListInteractor(type: .top))
                    .navigationTitle("Top")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Top", systemImage: "list.dash")
            }
            NavigationStack {
                StoriesListView(interactor: StoriesListInteractor(type: .new))
                    .navigationTitle("New")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("New", systemImage: "chart.line.uptrend.xyaxis")
            }
            NavigationStack {
                StoriesListView(interactor: StoriesListInteractor(type: .show))
                    .navigationTitle("Show")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Show", systemImage: "binoculars")
            }
            NavigationStack {
                StoriesListView(interactor: StoriesListInteractor(type: .ask))
                    .navigationTitle("Ask")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Ask", systemImage: "text.bubble")
            }
            if appRemoteConfig.isLoggedInEnabled() {
                NavigationStack {
                    LoggedInView()
                        .navigationTitle(titleForUser)
                        .navigationBarTitleDisplayMode(.inline)
                }
                .tabItem {
                    Label("User", systemImage: "person")
                }
            }
        }
        .onAppear {
            interactor.activate()
            UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = UIColor(named: "AccentColor")
        }
        .onReceive(keychainWrapper.isLoggedInSubject) { output in
            if output,
               let username = keychainWrapper.retrieve(for: .username) {
                titleForUser = username
            } else {
                titleForUser = "User"
            }
        }
        .onReceive(networkConnectivityManager.isConnectedPublisher) { output in
            showConnectionAlert = !output
        }
        .toast(isPresenting: $showConnectionAlert, duration: 5.0, tapToDismiss: true, offsetY: (UIScreen.main.bounds.size.height / 2) - 120, alert: {
            AlertToast(type: .regular, title: "No internet connection")
            
        }, onTap: nil, completion: nil)
    }
}
