//
//  UserHeaderView.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 13/1/2023.
//

import Foundation
import SwiftUI

struct UserHeaderView: View {
    let user: UserViewModel
    @Binding var displayingSafariURL: URL?
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(user.id)
                    .font(.title3)
                    .foregroundColor(Color.primary)
                Text(user.created)
                    .font(.callout)
                    .foregroundColor(.gray)
                if let about = user.about {
                    Text(about)
                        .font(.callout)
                        .foregroundColor(.gray)
                        .environment(\.openURL, OpenURLAction { url in
                            displayingSafariURL = url
                            return .handled
                        })
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                HStack {
                    Text(String(user.karma))
                        .font(.callout)
                        .foregroundColor(Color.accentColor)
                    Image(systemName: "arrow.up.square.fill")
                        .renderingMode(.template)
                        .foregroundColor(Color.accentColor)
                        .padding(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0))
                }
                HStack {
                    Text(String(user.submissions))
                        .font(.callout)
                        .foregroundColor(Color.gray)
                    Image(systemName: "text.bubble.fill")
                        .renderingMode(.template)
                        .foregroundColor(Color(uiColor: UIColor.systemGray3))
                }
            }
            .padding(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 0))
        }
    }
}
