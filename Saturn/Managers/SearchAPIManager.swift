//
//  SearchAPIManager.swift
//  Saturn
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
    
    let apiManager = APIManager()
    
    func search(query: String) -> AnyPublisher<[SearchResultItem], Error> {
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
        
        if query.components(separatedBy: CharacterSet.whitespaces).count == 1 {
            return Publishers.MergeMany(publisherForQuery(request: mutableRequest),
                                        publisherForUser(query: query))
                .eraseToAnyPublisher()
            
        } else {
            return publisherForQuery(request: mutableRequest)
        }
    }
    
    // MARK: -
    private func publisherForQuery(request: URLRequest) -> AnyPublisher<[SearchResultItem], Error> {
        return URLSession.DataTaskPublisher(request: request, session: .shared)
            .mapError { _ in APIManagerError.generic }
            .tryMap { (data: Data, urlResponse: URLResponse) -> SearchResponse in
                let decoder = JSONDecoder()
                return try decoder.decode(SearchResponse.self, from: data)
            }
            .map({ (response: SearchResponse) -> [SearchResultItem] in
                response.hits.map { SearchResultItem.searchResult($0) }
            })
            .eraseToAnyPublisher()
    }
    
    private func publisherForUser(query: String) -> AnyPublisher<[SearchResultItem], Error> {
        return apiManager.loadUser(id: query)
            .map { [SearchResultItem.user($0)] }
            .eraseToAnyPublisher()
    }
}
