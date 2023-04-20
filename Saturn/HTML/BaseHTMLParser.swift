//
//  BaseHTMLParser.swift
//  Saturn
//
//  Created by James Eunson on 20/4/2023.
//

import Foundation
import SwiftSoup

open class BaseHTMLParser {
    func extractNextPageItemId(element: Element) -> Int? {
        guard let hrefString = try? element.attr("href") else {
            return nil
        }
        guard let url = URL(string: "https://news.ycombinator.com/" + hrefString),
              let components = URLComponents(string: url.absoluteString),
              let queryItems = components.queryItems else {
            return nil
        }
        var id: Int?
        for item in queryItems {
            if item.name == "next",
               let value = item.value,
               let valueInt = Int(value) {
                id = valueInt
            }
        }
        return id
    }
}
