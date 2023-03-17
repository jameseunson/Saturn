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
    
    var body: some View {
        NavigationStack {
            List {
                TextField("Username", text: $username)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                SecureField("Password", text: $password)
                Button {
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
                } label: {
                    HStack {
                        Spacer()
                        Text("Login")
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding([.top, .bottom], 12)
                    .padding([.leading, .trailing], 30)
                    .background {
                        RoundedRectangle(cornerRadius: 10)
                            .foregroundColor( Color.accentColor )
                    }
                    .frame(maxWidth: .infinity)
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
        .alert(isPresented: $isDisplayingError, content: {
            Alert(title: Text("Error"), message: Text("Could not login, please try again later."), dismissButton: .default(Text("OK")))
        })
    }
}

struct LoggedInAuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            LoginAuthenticationView(isDisplayingLoginPrompt: .constant(true))
        }
        NavigationStack {
            LoginAuthenticationView(isDisplayingLoginPrompt: .constant(true), isDisplayingError: true)
        }
    }
}
