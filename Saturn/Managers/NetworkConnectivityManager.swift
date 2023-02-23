//
//  NetworkConnectivityManager.swift
//  Saturn
//
//  Created by James Eunson on 19/1/2023.
//

import Network
import SwiftUI

final class NetworkConnectivityManager {
    @Published var isConnected = false {
        didSet {
            print("isConnected: \(isConnected)")
        }
    }
    
    private let nwMonitor = NWPathMonitor()
    static let instance = NetworkConnectivityManager()
    
    public func start() {
        nwMonitor.start(queue: DispatchQueue.global())
        nwMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
    }
    
    public func stop() {
        nwMonitor.cancel()
    }
}
