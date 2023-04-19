//
//  APIManagerDecoder.swift
//  Saturn
//
//  Created by James Eunson on 29/3/2023.
//

import Foundation
import Combine

final class APIDecoder {
    func decodeResponse<T: Codable>(_ response: Any) -> AnyPublisher<T, Error> {
        return Future { promise in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let object: T = try self.decodeResponse(response)
                    
                    DispatchQueue.main.async {
                        promise(.success(object))
                    }
                    
                } catch let error {
                    promise(.failure(error))
                }
            }

        }
        .eraseToAnyPublisher()
    }
    
    func decodeResponse<T: Codable>(_ response: Any) throws -> T {
        if let dict = response as? Dictionary<String, Any> {
            if dict.keys.contains("deleted") {
                throw APIManagerError.deleted
            }
            if dict.keys.contains("dead") {
                throw APIManagerError.dead
            }
        }
        
        if response is NSNull {
            throw APIManagerError.noData
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: response)
        let object = try JSONDecoder().decode(T.self, from: jsonData)
        
        return object
    }
}
