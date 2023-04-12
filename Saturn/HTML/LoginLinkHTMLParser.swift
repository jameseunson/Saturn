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
        
        /// Check for login button in the top right hand corner of the page, indicating no active session
        let loginLinks = try doc.select("span.pagetop a")
        for link in loginLinks {
            let loginLinkText = try link.text().lowercased()
            if loginLinkText == "login" {
                return false
            }
        }
        
        /// Check for login form
        /// This can appear performing authenticated actions like vote/flag without a valid session
        /// eg. try loading this page while not logged in https://news.ycombinator.com/vote?id=35530965&how=up&goto=item%3Fid%3D35519224
        let loginSubmitButton = try doc.select("input[type='submit'][value='login']").first()
        if loginSubmitButton != nil {
            return false
        }
        
        return true
    }
}
