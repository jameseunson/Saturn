//
//  NetworkConnectivityManager.swift
//  Saturn
//
//  Created by James Eunson on 19/1/2023.
//

import Network
import SwiftUI
import Combine
import Factory

/// @mockable
protocol NetworkConnectivityManaging: AnyObject {
    var isConnectedPublisher: AnyPublisher<Bool, Never> { get }
    func start()
    func stop()
    func updateConnected(with isConnected: Bool)
    func isConnected() -> Bool
}

public final class NetworkConnectivityManager: NetworkConnectivityManaging {
    @Injected(\.globalErrorStream) private var globalErrorStream
    
    public var isConnectedPublisher: AnyPublisher<Bool, Never>
    private var disposeBag = Set<AnyCancellable>()
    deinit {
        disposeBag.forEach { $0.cancel() }
    }
    
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
        
        isConnectedPublisher
            .removeDuplicates()
            .filter { !$0 }
            .sink { isConnected in
                self.globalErrorStream.addError(NetworkConnectivityManagerError.notConnected)
            }
            .store(in: &disposeBag)
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

enum NetworkConnectivityManagerError: LocalizedError {
    case notConnected
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return NSLocalizedString(
                "No internet connection",
                comment: ""
            )
        }
    }
}
