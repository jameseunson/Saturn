//
//  LoggedInView.swift
//  Saturn
//
//  Created by James Eunson on 9/3/2023.
//

import Foundation
import SwiftUI

struct LoggedInView: View {
    @State var isDisplayingLoginPrompt: Bool = false
    @State var isLoggedIn: Bool = false
    
    var body: some View {
        VStack {
            Image(systemName: "person.fill")
                .resizable()
                .frame(width: 100, height: 100)
                .foregroundColor(.gray)
                .padding(.bottom, 16)
            Text("Login to HN")
                .font(.title)
                .padding(.bottom, 2)
            Text("Your account is stored privately and securely on your device.")
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .font(.callout)
                .padding(.bottom, 16)
            
            Button {
                isDisplayingLoginPrompt = true
            } label: {
                Text("Login to HN")
                    .foregroundColor(.white)
                    .padding([.top, .bottom], 12)
                    .padding([.leading, .trailing], 30)
                    .background {
                        RoundedRectangle(cornerRadius: 10)
                            .foregroundColor( Color.accentColor )
                    }
            }
        }
        .sheet(isPresented: $isDisplayingLoginPrompt, content: {
            LoginAuthenticationView(isDisplayingLoginPrompt: $isDisplayingLoginPrompt)
        })
        .onAppear {
            isLoggedIn = SaturnKeychainWrapper.shared.hasCredential()
        }
    }
}

struct LoggedInView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            LoggedInView()
        }
    }
}
