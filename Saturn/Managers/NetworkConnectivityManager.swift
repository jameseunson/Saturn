//
//  NetworkConnectivityManager.swift
//  Saturn
//
//  Created by James Eunson on 19/1/2023.
//

import Network
import SwiftUI
import Combine

/// @mockable
protocol NetworkConnectivityManaging: AnyObject {
    var isConnectedPublisher: AnyPublisher<Bool, Never> { get }
    func start()
    func stop()
    func updateConnected(with isConnected: Bool)
    func isConnected() -> Bool
}

public final class NetworkConnectivityManager: NetworkConnectivityManaging {
    public var isConnectedPublisher: AnyPublisher<Bool, Never>
    
    private var isConnectedSubject = CurrentValueSubject<Bool, Never>(true)
    private let nwMonitor = NWPathMonitor()
    
    init() {
        self.isConnectedPublisher = isConnectedSubject.removeDuplicates().eraseToAnyPublisher()
    }
    
    // MARK: - Public
    public func start() {
        nwMonitor.start(queue: DispatchQueue.global())
        nwMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnectedSubject.send(path.status == .satisfied)
            }
        }
    }
    
    public func stop() {
        nwMonitor.cancel()
    }
    
    public func updateConnected(with isConnected: Bool) {
        self.isConnectedSubject.send(isConnected)
    }
    
    public func isConnected() -> Bool {
        self.isConnectedSubject.value
    }
}
