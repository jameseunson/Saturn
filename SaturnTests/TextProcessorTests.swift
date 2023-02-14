//
//  TextProcessorTests.swift
//  SaturnTests
//
//  Created by James Eunson on 8/2/2023.
//

import Foundation
import XCTest
@testable import Saturn

final class TestProcessorTests: XCTestCase {
    
    // SwiftyMarkdown has a habit of interpreting underscores in URLs as italicization.
    // This test ensures underscore escaping in urls is working, which prevents underscores being mistakenly interpreted as italics, instead of simply underscores.
    func test_underscoresInUrl() {
        let rawText = "It is amusing that in 2005, &quot;VLDB&quot; (precursor term to &quot;big data&quot;) was defined in Wikipedia to be &quot;larger than 1TB&quot;.. after reading through the post and the author&#x27;s experience.. it would appear that this was not actually a completely terrible estimate, although there are larger and smaller: <a href=\"https:&#x2F;&#x2F;en.wikipedia.org&#x2F;w&#x2F;index.php?title=Very_large_database&amp;oldid=20738417\" rel=\"nofollow\">https:&#x2F;&#x2F;en.wikipedia.org&#x2F;w&#x2F;index.php?title=Very_large_databa...</a><p>The current version of that article states: &quot;There is no absolute amount of data that can be cited. For example, one cannot say that any database with more than 1 TB of data is considered a VLDB. This absolute amount of data has varied over time as computer processing, storage and backup methods have become better able to handle larger amounts of data.[5] That said, VLDB issues may start to appear when 1 TB is approached,[8][9] and are more than likely to have appeared as 30 TB or so is exceeded.[10]&quot;\n<a href=\"https:&#x2F;&#x2F;en.wikipedia.org&#x2F;wiki&#x2F;Very_large_database\" rel=\"nofollow\">https:&#x2F;&#x2F;en.wikipedia.org&#x2F;wiki&#x2F;Very_large_database</a>"
        
        do {
            let attributedString = try TextProcessor.processCommentText(rawText)
            var urlFound = false
            for (value, _) in attributedString.output.runs[\.link] {
                guard let value else { continue }
                
                if value.absoluteString == "https://en.wikipedia.org/wiki/Very_large_database" {
                    urlFound = true
                }
            }
            
            XCTAssert(urlFound)
            
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func test_parenthesisInUrl() {
        let rawText = "Honestly this espionage thing is overrated. Plenty of employees in the US take their knowledge to (domestic) competitors and find it quite hard to just clone a business. The Russians and US were stealing each other&#x27;s plans during the space race but this often led to misunderstood and suboptimal designs. See Buran<p><a href=\"https:&#x2F;&#x2F;wikipedia.org&#x2F;wiki&#x2F;Buran_(spacecraft)\" rel=\"nofollow\">https:&#x2F;&#x2F;wikipedia.org&#x2F;wiki&#x2F;Buran_(spacecraft)</a>"
        
        do {
            let attributedString = try TextProcessor.processCommentText(rawText)
            let string = String(attributedString.output.characters)
            
            var urlStringFound = false
            if string.contains("https://wikipedia.org/wiki/Buran_(spacecraft)") {
                urlStringFound = true
            }
            
            XCTAssert(urlStringFound)
            
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
}
