//
//  URL+CacheKey.swift
//  Saturn
//
//  Created by James Eunson on 29/3/2023.
//

import Foundation

extension URL {
    var cacheKey: String {
        return self.absoluteString.cacheKey
    }
}

extension String {
    var cacheKey: String {
        return self
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ".", with: "-")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-")).inverted)
            .joined()
    }
}
