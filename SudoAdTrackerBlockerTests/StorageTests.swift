//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import SudoAdTrackerBlocker

class StorageTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testFileStorage() async throws {

        let storage = FileSystemRulesetStorageProvider()
        let ruleSet = Ruleset(id: "/ad-tracker-blocker/filter-lists/adblock-plus/AD/easylist.txt", type: .adBlocking, name: "easylist.txt", eTag: "1", lastModified: Date(), size: 1)

        let testFileContents = "Listen to me. I know that new situations can be intimidating. You're lookin’ around and it’s all scary and different, but y’know … meeting them head-on, charging into ‘em like a bull — that’s how we grow as people."
        let data = testFileContents.data(using: .utf8)!
        try await storage.save(ruleset: ruleSet, data: data)

        let returnedData = await storage.read(ruleset: ruleSet)
        guard let readData = returnedData?.data else {
            XCTFail()
            return
        }

        XCTAssertEqual(String(data: readData, encoding: .utf8), testFileContents)
    }

    func testExceptionsProvider() async {
        let storage = DefaultExceptionProvider()
        let host = BlockingException("host.com")
        let exceptions = [
            BlockingException("page.com/"),
            BlockingException("page2.com")
        ]
        var array = await storage.get()
        XCTAssertEqual(array, [])

        var exceptionsWithHost = [host]
        exceptionsWithHost.append(contentsOf: exceptions)

        await storage.add(exceptionsWithHost)

        array = await storage.get()
        XCTAssertEqual(array, exceptionsWithHost)

        await storage.remove([host])
        
        array = await storage.get()
        XCTAssertEqual(array, exceptions)

        await storage.removeAll()
        array = await storage.get()
        XCTAssertEqual(array, [])
    }
}
