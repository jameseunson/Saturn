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
    let submissions: String
    let karma: String
    
    init(user: User) {
        self.id = user.id
        self.about = user.about
        self.created = "Created \(RelativeDateTimeFormatter().localizedString(for: user.created, relativeTo: Date()))"
        
        if user.submitted.count >= 1000 {
            self.submissions = String(format: "%.1f", Double(user.submitted.count) / 1000) + "k"
        } else {
            self.submissions = String(user.submitted.count)
        }
        
        if user.karma >= 1000 {
            self.karma = String(format: "%.1f", Double(user.karma) / 1000) + "k"
        } else {
            self.karma = String(user.karma)
        }
    }
}
