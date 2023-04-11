//
//  SaturnKeychainWrapper.swift
//  Saturn
//
//  Created by James Eunson on 17/03/2023.
//

import AuthenticationServices
import Combine
import Foundation

/// @mockable
protocol SaturnKeychainWrapping: AnyObject {
    @discardableResult func store(cookie: String, username: String, password: String) -> Bool
    func clearCredential()
    func hasCredential() -> Bool
    func retrieve(for key: KeychainItemKeys) -> String?
    var isLoggedIn: Bool { get }
    var isLoggedInSubject: CurrentValueSubject<Bool, Never> { get }
}

final class SaturnKeychainWrapper: SaturnKeychainWrapping {
    private let keychain = KeychainItem(service: "au.jameseunson.Saturn")
    
    public var isLoggedInSubject = CurrentValueSubject<Bool, Never>(false)
    
    public var isLoggedIn: Bool {
        isLoggedInSubject.value
    }
    
    init(loginOverride: Bool? = nil) {
        if let loginOverride {
            isLoggedInSubject.send(loginOverride)
        } else {
            isLoggedInSubject.send(hasCredential())
        }
    }
    
    @discardableResult
    func store(cookie: String, username: String, password: String) -> Bool {
        do {
            try keychain.deleteItem(account: KeychainItemKeys.cookie.rawValue)
            try keychain.deleteItem(account: KeychainItemKeys.username.rawValue)
            try keychain.deleteItem(account: KeychainItemKeys.password.rawValue)
            
            try keychain.saveItem(account: KeychainItemKeys.cookie.rawValue, cookie)
            try keychain.saveItem(account: KeychainItemKeys.username.rawValue, username)
            try keychain.saveItem(account: KeychainItemKeys.password.rawValue, password)
            
            DispatchQueue.main.async { [weak self] in
                self?.isLoggedInSubject.send(true)
            }
            
            return true
        } catch {
            return false
        }
    }
    
    func clearCredential() {
        try? keychain.deleteItem(account: KeychainItemKeys.cookie.rawValue)
        try? keychain.deleteItem(account: KeychainItemKeys.username.rawValue)
        try? keychain.deleteItem(account: KeychainItemKeys.password.rawValue)
        
        isLoggedInSubject.send(false)
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
    case password
    case cookie
}
