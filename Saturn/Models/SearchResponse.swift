//
//  SearchResponse.swift
//  Saturn
//
//  Created by James Eunson on 19/1/2023.
//

import Foundation

struct SearchResponse: Codable {
//    let users: [User]
    let hits: [SearchItem]
}
