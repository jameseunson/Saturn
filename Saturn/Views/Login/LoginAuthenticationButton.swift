//
//  LoginAuthenticationButton.swift
//  Saturn
//
//  Created by James Eunson on 20/3/2023.
//

import Foundation
import SwiftUI

struct LoginAuthenticationButton: View {
    @GestureState private var isTapped = false
    
    @Binding var isLoading: Bool
    @Binding var isDisabled: Bool
    
    let onTap: (() -> Void)
    
    
    var body: some View {
        Button {
            if isDisabled { return }
            onTap()
            
        } label: {
            HStack {
                Spacer()
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Login")
                        .foregroundColor(.white)
                }
                Spacer()
            }
            .padding([.top, .bottom], 12)
            .padding([.leading, .trailing], 30)
            .background {
                if isTapped {
                    RoundedRectangle(cornerRadius: 10).foregroundColor(Color("AccentColorDark"))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .foregroundColor(Color.accentColor.opacity((isLoading || isDisabled) ? 0.7 : 1.0))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .updating($isTapped) { (_, isTapped, _) in
                isTapped = true
            })
        .buttonStyle(PlainButtonStyle())
    }
}
