//
//  ViewAllCommentsButton.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 2/2/2023.
//

import Foundation
import SwiftUI

struct ViewAllCommentsButton: View {
    @Binding var displayFullComments: Bool
    
    var body: some View {
        VStack {
            Spacer()
            Button {
                displayFullComments = true
            } label: {
                HStack {
                    Text("View all comments")
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white)
                }
                .padding()
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .foregroundColor(.primary)
            .background {
                Rectangle()
                    .cornerRadius(8)
                    .foregroundColor(Color.accentColor)
            }
        }
        .padding()
    }
}

