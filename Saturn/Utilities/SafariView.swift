//
//  SafariView.swift
//  Saturn
//
//  Created by James Eunson on 15/9/2022.
//

import Foundation
import SafariServices
import SwiftUI
import Factory

struct SafariView: UIViewControllerRepresentable {
    @Injected(\.settingsManager) private var settingsManager
    let url: URL
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<SafariView>) -> SFSafariViewController {
        
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = settingsManager.bool(for: .entersReader)
        
        let vc = SFSafariViewController(url: url, configuration: configuration)
        vc.preferredControlTintColor = UIColor(Color.accentColor)
        
        return vc
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: UIViewControllerRepresentableContext<SafariView>) {}
}
