//
//  LoggedInAuthenticationView.swift
//  Saturn
//
//  Created by James Eunson on 17/3/2023.
//

import Foundation
import SwiftUI

struct LoginAuthenticationView: View {
    @StateObject var interactor = LoginAuthenticationInteractor()
    
    @Binding var isDisplayingLoginPrompt: Bool
    
    @State var username: String = ""
    @State var password: String = ""
    @State var isDisplayingError = false
    
    @State var isLoading: Bool = false
    
    var body: some View {
        NavigationStack {
            List {
                TextField("Username", text: $username)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                SecureField("Password", text: $password)
                LoginAuthenticationButton(isLoading: $isLoading,
                                          isDisabled: submitDisabled()) {
                    Task {
                        do {
                            if try await interactor.login(with: username,
                                                          password: password) {
                                isDisplayingLoginPrompt = false
                            } else {
                                isDisplayingError = true
                            }
                        } catch {
                            isDisplayingError = true
                        }
                    }
                }
            }
            .navigationTitle("Login")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button {
                        isDisplayingLoginPrompt = false
                    } label: {
                        Text("Cancel")
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .onAppear {
            interactor.activate()
        }
        .onReceive(interactor.$isLoading, perform: { output in
            isLoading = output
        })
        .alert(isPresented: $isDisplayingError, content: {
            Alert(title: Text("Error"), message: Text("Could not login, please try again later."), dismissButton: .default(Text("OK")))
        })
    }
    
    func submitDisabled() -> Binding<Bool> {
        Binding {
            username.isEmpty || password.isEmpty
        } set: { _ in }
    }
}

struct LoggedInAuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            LoginAuthenticationView(interactor: LoginAuthenticationInteractor(isLoading: false),
                                    isDisplayingLoginPrompt: .constant(true))
        }
        NavigationStack {
            LoginAuthenticationView(interactor: LoginAuthenticationInteractor(isLoading: false),
                                    isDisplayingLoginPrompt: .constant(true),
                                    isDisplayingError: true)
        }
        NavigationStack {
            LoginAuthenticationView(interactor: LoginAuthenticationInteractor(isLoading: true),
                                    isDisplayingLoginPrompt: .constant(true))
        }
    }
}
