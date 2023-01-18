//
//  SearchAPIManager.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 18/1/2023.
//

import Foundation
import Combine

final class SearchAPIManager {
    let baseURLString = "https://uj5wyc0l7x-dsn.algolia.net/1/indexes/Item_production_ordered/query"
    
    let urlParams = ["x-algolia-agent": "Algolia for JavaScript (4.0.2); Browser (lite)",
                     "x-algolia-api-key": "8ece23f8eb07cd25d40262a1764599b1",
                     "x-algolia-application-id": "UJ5WYC0L7X"]
    
    let originReferer = "https://hn.algolia.com"
    let contentType = "application/x-www-form-urlencoded"
    let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36"
    
    let postBody = """
    {"query":"%s","analyticsTags":["web"],"page":0,"hitsPerPage":30,"minWordSizefor1Typo":4,"minWordSizefor2Typos":8,"advancedSyntax":true,"ignorePlurals":false,"clickAnalytics":true,"minProximity":7,"numericFilters":[],"tagFilters":["story",[]],"typoTolerance":true,"queryType":"prefixNone","restrictSearchableAttributes":["title","comment_text","url","story_text","author"],"getRankingInfo":true}:
    """
    
    func search(query: String) -> AnyPublisher<SearchResponse?, Error> {
        guard var urlComponents = URLComponents(string: baseURLString) else {
            return Fail(error: APIManagerError.generic).eraseToAnyPublisher()
        }
        
        var queryItems = [URLQueryItem]()
        for (k, v) in urlParams {
            queryItems.append(URLQueryItem(name: k, value: v))
        }
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            return Fail(error: APIManagerError.generic).eraseToAnyPublisher()
        }
        
        var mutableRequest = URLRequest(url: url)
        mutableRequest.httpMethod = "POST"
        
        mutableRequest.addValue(originReferer, forHTTPHeaderField: "Origin")
        mutableRequest.addValue(originReferer, forHTTPHeaderField: "Referer")
        mutableRequest.addValue(userAgent, forHTTPHeaderField: "User-Agent")
        mutableRequest.addValue(contentType, forHTTPHeaderField: "Content-Type")

        let queryPostBody = postBody.replacingOccurrences(of: "%s", with: query)
        mutableRequest.httpBody = queryPostBody.data(using: .utf8)
        
        return URLSession.DataTaskPublisher(request: mutableRequest, session: .shared)
            .mapError { _ in APIManagerError.generic }
            .map { (data: Data, urlResponse: URLResponse) -> SearchResponse? in
//                print(String(data: data, encoding: .utf8))
                return self.decodeResponse(data: data)
            }
            .eraseToAnyPublisher()
    }
    
    private func decodeResponse<T: Decodable>(data: Data) -> T? {
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch let error {
            print(error)
            return nil
        }
    }
}

struct SearchResponse: Codable {
    let hits: [SearchItem]
}

struct SearchItem: Codable {
    let createdAt: Date
    let title: String
    let url: URL?
    let author: String
    let points: Int
    let numComments: Int
    let objectID: Int
    
    enum CodingKeys: String, CodingKey {
        case createdAt = "created_at_i"
        case title
        case url
        case author
        case points
        case numComments = "num_comments"
        case objectID
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let rawDate = try container.decode(TimeInterval.self, forKey: .createdAt)
        self.createdAt = Date(timeIntervalSince1970: rawDate)
        
        self.title = try container.decode(String.self, forKey: .title)
        self.url = try container.decodeIfPresent(URL.self, forKey: .url)
        self.author = try container.decode(String.self, forKey: .author)
        self.points = try container.decode(Int.self, forKey: .points)
        self.numComments = try container.decode(Int.self, forKey: .numComments)
        
        let objectID = try container.decode(String.self, forKey: .objectID)
        if let objectIDInt = Int(objectID) {
            self.objectID = objectIDInt
        } else {
            throw SearchItemError.invalidObjectID
        }
    }
}

enum SearchItemError: Error {
    case invalidObjectID
}
