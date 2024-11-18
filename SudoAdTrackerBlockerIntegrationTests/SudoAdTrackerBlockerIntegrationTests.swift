//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import SudoAdTrackerBlocker
import WebKit

class SudoAdTrackerBlockerIntegrationTests: IntegrationTestBase {

    var client: SudoAdTrackerBlockerClient!
    var store: WKContentRuleListStore!

    override func setUp() async throws {
        try await super.setUp()
        let clientConfig = try SudoAdTrackerBlockerConfig(userClient: self.userClient)
        self.client = DefaultSudoAdTrackerBlockerClient(config: clientConfig)

        try await self.client.reset()
        let storeURL = FileManager.default.temporaryDirectory
        await MainActor.run {
            // Main actor required for WKContentRuleListStore init
            self.store = WKContentRuleListStore.init(url: storeURL)
        }
    }

    /// Tests that we can list the rulesets and that a ruleset can be compiled
    func testListAndCompileRulesets() async throws {
        let rulesets = try await self.client.listRulesets()
        XCTAssertGreaterThan(rulesets.count , 0)
        guard let easyPrivacy = rulesets.filter({$0.name.contains("easyprivacy")}).first else {
            XCTFail("easyprivacy not found, cannot test list compilation.")
            throw "easyprivacy not found, cannot test list compilation."
        }
        do {
            try await self.testContentBlockerCompiles(ruleset: easyPrivacy)
        } catch {
            XCTFail("Ruleset not compiled.")
        }
    }

    func testContentBlockerCompiles(ruleset: Ruleset) async throws {
        let blocker = try await self.client.getContentBlocker(ruleset: ruleset)
        try await self.store.compileContentRuleList(forIdentifier: blocker.id, encodedContentRuleList: blocker.rulesetData)
    }
}
