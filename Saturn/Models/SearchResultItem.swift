//
//  SearchResultItem.swift
//  Saturn
//
//  Created by James Eunson on 26/1/2023.
//

import Foundation

enum SearchResultItem: Codable, Hashable, Identifiable {
    static func == (lhs: SearchResultItem, rhs: SearchResultItem) -> Bool {
        switch (lhs, rhs) {
        case let (.searchResult(lhsResult), .searchResult(rhsResult)):
            return lhsResult == rhsResult
        case let (.user(lhsResult), .user(rhsResult)):
            return lhsResult == rhsResult
        default:
            return false
        }
    }
    
    var id: Int {
        switch self {
        case let .searchResult(searchItem):
            return searchItem.objectID
        case let .user(user):
            return user.hashValue
        }
    }
    
    case searchResult(SearchItem)
    case user(User)
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case let .searchResult(searchItem):
            hasher.combine(searchItem)
        case let .user(user):
            hasher.combine(user)
        }
    }
}
