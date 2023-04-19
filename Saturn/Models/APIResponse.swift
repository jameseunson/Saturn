//
//  APIResponse.swift
//  Saturn
//
//  Created by James Eunson on 12/4/2023.
//

import Foundation

enum APIManagerError: Error {
    case generic
    case deleted
    case noData
    case dead
}

struct APIResponse<T>: Codable where T: Codable {
    let response: T
    let source: APIResponseLoadSource
}

enum APIResponseLoadSource: Codable {
    case network
    case cache
}

enum APIManagerNetworkError: LocalizedError {
    case timeout
    case unrecognizedItemType
    
    var errorDescription: String? {
        switch self {
        case .timeout:
            return NSLocalizedString(
                "Loading took too long to complete. Your connection may be experiencing issues.",
                comment: ""
            )
        case .unrecognizedItemType:
            return NSLocalizedString(
                "Could not load specified type of story.",
                comment: ""
            )
        }
    }
}
