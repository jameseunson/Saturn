//
//  SafariView.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 15/9/2022.
//

import Foundation
import SafariServices
import SwiftUI

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<SafariView>) -> SFSafariViewController {
        
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = Settings.default.bool(for: .entersReader)
        
        let vc = SFSafariViewController(url: url, configuration: configuration)
        vc.preferredControlTintColor = UIColor(Color.accentColor)
        
        return vc
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: UIViewControllerRepresentableContext<SafariView>) {}
}
