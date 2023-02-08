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
    
    let onTapUser: ((String) -> Void)
    let onTapStoryId: ((Int) -> Void)
    let onTapURL: ((URL) -> Void)
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.id)
                        .font(.title3)
                        .foregroundColor(Color.primary)
                    Text(user.created)
                        .font(.callout)
                        .foregroundColor(.gray)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    HStack {
                        Text(user.karma)
                            .font(.callout)
                            .foregroundColor(Color.accentColor)
                        Image(systemName: "arrow.up.square.fill")
                            .renderingMode(.template)
                            .foregroundColor(Color.accentColor)
                            .padding(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0))
                    }
                    HStack {
                        Text(user.submissions)
                            .font(.callout)
                            .foregroundColor(Color.gray)
                        Image(systemName: "text.bubble.fill")
                            .renderingMode(.template)
                            .foregroundColor(Color(uiColor: UIColor.systemGray3))
                    }
                }
                .padding(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 0))
            }
            .padding(.bottom, user.about == nil ? 0 : 10)
            
            if let about = user.about {
                Divider()
                Text(about)
                    .font(.callout)
                    .foregroundColor(.gray)
                    .modifier(TextLinkHandlerModifier(onTapUser: onTapUser,
                                                      onTapStoryId: onTapStoryId,
                                                      onTapURL: onTapURL))
            }
        }
    }
}
