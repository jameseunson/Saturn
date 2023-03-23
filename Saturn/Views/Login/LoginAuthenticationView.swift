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
    @State var isDisplayingForgotPasswordView = false
    
    @State var isLoading: Bool = false
    
    @FocusState private var isUsernameFocused: Bool
    @FocusState private var isPasswordFocused: Bool
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray.opacity(0.5))
                        TextField("Username", text: $username)
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.never)
                            .textContentType(.username)
                            .focused($isUsernameFocused)
                            .disabled(isLoading)
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    
                                    HStack {
                                        Button {
                                            isUsernameFocused = true
                                        } label: {
                                            Image(systemName: "chevron.left")
                                        }
                                        .disabled(isUsernameFocused)
                                        
                                        Button {
                                            isPasswordFocused = true
                                        } label: {
                                            Image(systemName: "chevron.right")
                                        }
                                        .disabled(isPasswordFocused)

                                        Spacer()
                                        Button {
                                            isUsernameFocused = false
                                            isPasswordFocused = false
                                        } label: {
                                            Text("Done")
                                                .fontWeight(.semibold)
                                        }
                                    }
                                }
                            }
                            .submitLabel(.next)
                    }
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.gray.opacity(0.5))
                        SecureField("Password", text: $password)
                            .focused($isPasswordFocused)
                            .textContentType(.password)
                            .submitLabel(.done)
                            .disabled(isLoading)
                    }
                    LoginAuthenticationButton(isLoading: $isLoading,
                                              isDisabled: submitDisabled()) {
                        doLogin()
                    }
                } footer: {
                    HStack {
                        Spacer()
                        Button {
                            isDisplayingForgotPasswordView = true
                        } label: {
                            Text("Forgot password")
                                .foregroundColor(.accentColor)
                                .font(.callout)
                                .padding(.top, 10)
                        }
                        Spacer()
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
        .onSubmit {
            if isUsernameFocused {
                isPasswordFocused = true
                
            } else if isPasswordFocused {
                doLogin()
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
        .sheet(isPresented: $isDisplayingForgotPasswordView) {
            if let url = URL(string: "https://news.ycombinator.com/forgot") {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
    }
    
    func submitDisabled() -> Binding<Bool> {
        Binding {
            username.isEmpty || password.isEmpty
        } set: { _ in }
    }
    
    func doLogin() {
        if submitDisabled().wrappedValue { return }
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
