//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import XCTest
@testable import SudoAdTrackerBlocker
import WebKit
class ContentBlockerBuilderTests: XCTestCase {

    var store: WKContentRuleListStore!

    override func setUpWithError() throws {
        let storeURL = FileManager.default.temporaryDirectory
        self.store = WKContentRuleListStore.init(url: storeURL)
    }

    override func tearDownWithError() throws {
    }

    func testNoExpectionsReturnsBaseRuleset() throws {
        let testRuleset = try String(contentsOf: Bundle(for: ContentBlockerBuilderTests.self).url(forResource: "testRuleset", withExtension: "json")!)
        let ruleset = Ruleset(id: "test", type: .adBlocking, name: "test", eTag: "1", lastModified: Date(), size: testRuleset.count)
        let rulesetData = RulesetData(meta: ruleset, data: testRuleset.data(using: .utf8)!)

        let builder = ContentBlockerBuilder(rulesetData: rulesetData)
        let blocker = builder.buildWithExceptions(exceptions: [])!
        XCTAssertEqual(blocker.rulesetData, testRuleset)
        self.testContentBlockerCompiles(blocker: blocker)
    }

    func testExceptionsAdded() throws {
        let testRuleset = try String(contentsOf: Bundle(for: ContentBlockerBuilderTests.self).url(forResource: "testRuleset", withExtension: "json")!)
        let ruleset = Ruleset(id: "test", type: .adBlocking, name: "test", eTag: "1", lastModified: Date(), size: testRuleset.count)
        let rulesetData = RulesetData(meta: ruleset, data: testRuleset.data(using: .utf8)!)

        let exceptions: [BlockingException] = [BlockingException("google.com"),
                                               BlockingException("en.wikipedia.org"),
                                               BlockingException("*yahoo.com")]

        let builder = ContentBlockerBuilder(rulesetData: rulesetData)
        let blocker = builder.buildWithExceptions(exceptions: exceptions)!

        XCTAssertEqual(blocker.exceptions, exceptions)

        // Parse the json ruleset and dig down into the json for the added exceptions.
        // The json is an array of hashes. The one we are interested in should be the last in the list.
        guard let json = (try? JSONSerialization.jsonObject(with: blocker.rulesetData.data(using: .utf8)!, options: .init())) as? [[String: Any]] else {
            XCTFail("Failed to convert returned rule list to json")
            return
        }

        // We expect this to be the exceptions we added.  Dig down into the json for the "if-domain" chunk where the exceptions were added.
        let exceptionJSON = json.last
        guard let trigger = exceptionJSON?["trigger"] as? [String: Any] , let ifDomain = trigger["if-domain"] as? [String] else {
            XCTFail("Failed to read exception domain list from json")
            return
        }

        XCTAssertEqual(ifDomain.count, 3)
        XCTAssertTrue(ifDomain.contains("*google.com"))
        XCTAssertTrue(ifDomain.contains("*en.wikipedia.org"))

        // Make sure a double * wasn't added to the beginning of the exception.
        XCTAssertTrue(ifDomain.contains("*yahoo.com"))
    }

    func testContentBlockerCompiles(blocker: ContentBlocker) {
        // Make sure the builder returns a valid rulelist that can be compiled by webkit
        let compileExpectation = self.expectation(description: "Wait on rule list compile")
        self.store.compileContentRuleList(forIdentifier: blocker.id, encodedContentRuleList: blocker.rulesetData) { (compiledList, error) in
            XCTAssertNil(error)
            XCTAssertNotNil(compiledList)
            compileExpectation.fulfill()
        }
        self.waitForExpectations(timeout: 60, handler: nil)
    }
}
