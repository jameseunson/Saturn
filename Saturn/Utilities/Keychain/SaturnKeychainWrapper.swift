//
//  SaturnKeychainWrapper.swift
//  Saturn
//
//  Created by James Eunson on 17/03/2023.
//

import AuthenticationServices
import Combine
import Foundation

protocol SaturnKeychainWrapping: ObservableObject {
    @discardableResult func store(cookie: String) -> Bool
    func clearCredential()
    func hasCredential() -> Bool
    func retrieve(for key: KeychainItemKeys) -> String?
}

final class SaturnKeychainWrapper: SaturnKeychainWrapping {
    private let keychain = KeychainItem(service: "au.jameseunson.Saturn")
    static let shared = SaturnKeychainWrapper()
    
    @discardableResult
    func store(cookie: String) -> Bool {
        do {
            try keychain.deleteItem(account: KeychainItemKeys.cookie.rawValue)
            try keychain.saveItem(account: KeychainItemKeys.cookie.rawValue, cookie)
            
            return true
        } catch {
            return false
        }
    }
    
    func clearCredential() {
        try? keychain.deleteItem(account: KeychainItemKeys.cookie.rawValue)
    }
    
    func hasCredential() -> Bool {
        retrieve(for: .cookie) != nil
    }
    
    func retrieve(for key: KeychainItemKeys) -> String? {
        return try? keychain.readItem(account: key.rawValue)
    }
}

enum KeychainItemKeys: String, CodingKey {
    case cookie
}
