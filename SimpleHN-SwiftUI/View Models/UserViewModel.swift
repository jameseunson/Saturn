//
//  UserViewModel.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 13/1/2023.
//

import Foundation

struct UserViewModel: Codable, Hashable, Identifiable {
    let id: String
    let about: AttributedString?
    let created: String
    let submissions: Int
    let karma: Int
    
    init(user: User) {
        self.id = user.id
        self.about = user.about
        self.created = "Created \(RelativeDateTimeFormatter().localizedString(for: user.created, relativeTo: Date()))"
        self.submissions = user.submitted.count
        self.karma = user.karma
    }
}
