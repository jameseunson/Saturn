//
//  LoginLinkHTMLParser.swift
//  Saturn
//
//  Created by James Eunson on 11/4/2023.
//

import Foundation
import SwiftSoup

/// If the login link is visible in the html, we can surmise the user is not currently logged in,
/// the active session is invalid and the user must be re-authenticated to proceed
final class LoginLinkHTMLParser {
    func checkUserAuthenticated(_ htmlString: String) throws -> Bool  {
        let doc: Document = try SwiftSoup.parse(htmlString)
        
        let loginLinks = try doc.select("span.pagetop a")
        for link in loginLinks {
            let loginLinkText = try link.text().lowercased()
            if loginLinkText == "login" {
                return false
            }
        }
        
        return true
    }
}
