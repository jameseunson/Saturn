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
    @discardableResult func store(cookie: String, username: String) -> Bool
    func clearCredential()
    func hasCredential() -> Bool
    func retrieve(for key: KeychainItemKeys) -> String?
}

final class SaturnKeychainWrapper: SaturnKeychainWrapping {
    private let keychain = KeychainItem(service: "au.jameseunson.Saturn")
    static let shared = SaturnKeychainWrapper()
    
    @Published public var isLoggedIn: Bool = false
    
    init() {
        isLoggedIn = hasCredential()
    }
    
    @discardableResult
    func store(cookie: String, username: String) -> Bool {
        do {
            try keychain.deleteItem(account: KeychainItemKeys.cookie.rawValue)
            try keychain.deleteItem(account: KeychainItemKeys.username.rawValue)
            
            try keychain.saveItem(account: KeychainItemKeys.cookie.rawValue, cookie)
            try keychain.saveItem(account: KeychainItemKeys.username.rawValue, username)
            
            DispatchQueue.main.async { [weak self] in
                self?.isLoggedIn = true
            }
            
            return true
        } catch {
            return false
        }
    }
    
    func clearCredential() {
        try? keychain.deleteItem(account: KeychainItemKeys.cookie.rawValue)
        try? keychain.deleteItem(account: KeychainItemKeys.username.rawValue)
        
        isLoggedIn = false
    }
    
    func hasCredential() -> Bool {
        retrieve(for: .cookie) != nil && retrieve(for: .username) != nil
    }
    
    func retrieve(for key: KeychainItemKeys) -> String? {
        return try? keychain.readItem(account: key.rawValue)
    }
}

enum KeychainItemKeys: String, CodingKey {
    case username
    case cookie
}
