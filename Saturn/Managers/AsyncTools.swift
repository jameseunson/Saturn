//
//  AsyncAwaitTools.swift
//  Saturn
//
//  Created by James Eunson on 12/4/2023.
//

import Foundation
import Combine

final class AsyncTools {
    static func publisherForAsync<T>(action: @escaping () async throws -> T) -> AnyPublisher<T, Error> {
        return Future { promise in
            Task {
                do {
                    let output = try await action()
                    promise(.success(output))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}
