//
//  LoggedInView.swift
//  Saturn
//
//  Created by James Eunson on 9/3/2023.
//

import Foundation
import SwiftUI
import Factory

struct LoggedInView: View {
    @Injected(\.keychainWrapper) private var keychainWrapper
    
    @State var isDisplayingLoginPrompt: Bool = false
    @State var isLoggedIn: Bool = false
    @State var isDisplayingLogoutConfirm: Bool = false
    
    var body: some View {
        ZStack {
            if isLoggedIn,
            let username = keychainWrapper.retrieve(for: .username) {
                UserView(interactor: UserInteractor(username: username))
                
            } else {
                VStack {
                    Image(systemName: "person.fill")
                        .resizable()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.gray)
                        .padding(.bottom, 16)
                    Text("Login to HN")
                        .font(.title)
                        .padding(.bottom, 2)
                    Text("Your account is stored privately and securely on your device keychain.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .font(.callout)
                        .padding(.bottom, 16)
                        .padding([.leading, .trailing], 60)
                    
                    Button {
                        isDisplayingLoginPrompt = true
                    } label: {
                        Text("Login")
                            .foregroundColor(.white)
                            .padding([.top, .bottom], 12)
                            .padding([.leading, .trailing], 110)
                            .background {
                                RoundedRectangle(cornerRadius: 10)
                                    .foregroundColor( Color.accentColor )
                            }
                    }
                }
            }
        }
        .sheet(isPresented: $isDisplayingLoginPrompt, content: {
            LoginAuthenticationView(isDisplayingLoginPrompt: $isDisplayingLoginPrompt)
        })
        .onReceive(keychainWrapper.isLoggedInSubject, perform: { output in
            isLoggedIn = output
        })
        .toolbar {
            if isLoggedIn {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        isDisplayingLogoutConfirm = true
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.accentColor)
                    }
                }
            }
        }
        .confirmationDialog("Logout?", isPresented: $isDisplayingLogoutConfirm, actions: {
            Button(role: .destructive) {
                keychainWrapper.clearCredential()
                isLoggedIn = false
            } label: {
                Text("Logout")
            }
        })
    }
}

struct LoggedInView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            LoggedInView()
        }
    }
}
