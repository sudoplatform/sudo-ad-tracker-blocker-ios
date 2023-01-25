//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import AWSS3
@testable import SudoAdTrackerBlocker
import SudoUser

class SudoAdTrackerBlockerTests: XCTestCase {

    var mockSudoUserClient: MockSudoUserClient!
    var config: SudoAdTrackerBlockerConfig!
    var rulesetProvider: MockRulesetStorageProvider!
    var mockS3Client: MockS3Client!
    var client: DefaultSudoAdTrackerBlockerClient!
    var exceptionProvider: MockExceptionProvider!

    override func setUpWithError() throws {
        self.mockSudoUserClient = MockSudoUserClient()
        self.config = SudoAdTrackerBlockerConfig(userClient: self.mockSudoUserClient, region: "us-east-1", poolId: "poolid", identityPoolId: "idpoolid", bucket: "bucket")
        self.rulesetProvider = MockRulesetStorageProvider()
        self.mockS3Client = MockS3Client()
        self.exceptionProvider = MockExceptionProvider()

        self.client = DefaultSudoAdTrackerBlockerClient(config: self.config, storageProvider: self.rulesetProvider, s3Client: self.mockS3Client, exceptionProvider: self.exceptionProvider)
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testListRulesetsReturnsExpectedError() async throws {

        // Set the S3 client to return a download error to make sure it's caught
        self.mockS3Client.listObjectsV2InResult = .failure(NSError.some)

        do {
            let _ = try await self.client.listRulesets()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as NSError, NSError.some)
        }

        XCTAssertTrue(self.mockS3Client.listObjectsV2InCalled)
    }

    func testListRulesetsReturnsExpectedList() async throws {
        // Set the S3 client to return a known list
        let easyList = AWSS3Object(key: "/ad-tracker-blocker/filter-lists/adblock-plus/AD/easylist.txt", eTag: "froopyland", lastModified: Date(), size: 1)

        // Ad in a list that will fail parsing because the key will fail
        let unknownList = AWSS3Object(key: "helloWorld.txt", eTag: "froopyland", lastModified: Date(), size: 1)
        XCTAssertNil(Ruleset(s3Object: unknownList), "Test that a S3 object will fail conversion to ruleset.")

        // Set the mock data to be returned.
        self.mockS3Client.listObjectsV2InResult = .success(AWSS3ListObjectsV2Output(contents: [easyList, unknownList]))
        // We only get 1 result even though we passed in 2 objects.  Only one will be converted to a ruleset, the other fails.
        let list = try await self.client.listRulesets()
        XCTAssertEqual(list.count, 1)
    }

    func testDownloadRuleset() async throws {
        let ruleset = Ruleset(id: "Asimov", type: .adBlocking, name: "RulesForRobots", eTag: "tag", lastModified: Date(), size: 1)

        let _ = try await self.client.getRuleset(ruleset: ruleset)
        // Check the client passed the correct params trying to download the ruleset
        XCTAssertEqual(self.mockS3Client.downloadDataForParamRuleset?.id, ruleset.id)
        XCTAssertEqual(self.mockS3Client.downloadDataForParamBucket, self.config.bucket)

        // Check the client cached the result
        await XCTAssertTrueAsync(await self.rulesetProvider.saveCalled)
        try await XCTAssertEqualAsync(await self.rulesetProvider.saveParamRuleset?.id, ruleset.id)
    }

    func testDownloadRuleset_returnsCachedData() async throws {
        let ruleset = Ruleset(id: "Asimov", type: .adBlocking, name: "RulesForRobots", eTag: "tag", lastModified: Date(), size: 1)

        let r = RulesetData(meta: ruleset, data: "ruleseAreForTheWeak".data(using: .utf8)!)
        await self.rulesetProvider.set(readResult: r)

        let _ = try await self.client.getRuleset(ruleset: ruleset)
        // Confirm the client didn't attempt to download data
        XCTAssertFalse(self.mockS3Client.downloadDataForCalled)
        await XCTAssertTrueAsync(await self.rulesetProvider.readCalled)
    }

    func testDownloadRuleset_eTagMismatch() async throws {
        // Same data, different eTag
        let outOfDateRuleset = Ruleset(id: "Asimov", type: .adBlocking, name: "RulesForRobots", eTag: "0", lastModified: Date(), size: 1)
        let latestRuleset = Ruleset(id: "Asimov", type: .adBlocking, name: "RulesForRobots", eTag: "1", lastModified: Date(), size: 1)

        let r = RulesetData(meta: outOfDateRuleset, data: "ruleseAreForTheWeak".data(using: .utf8)!)
        await self.rulesetProvider.set(readResult: r)

        let _ = try await self.client.getRuleset(ruleset: latestRuleset)
        // Confirm the client was called to download the data even though it was cached
        await XCTAssertTrueAsync(await self.rulesetProvider.readCalled)
        XCTAssertTrue(self.mockS3Client.downloadDataForCalled)

        await XCTAssertTrueAsync(await self.rulesetProvider.saveCalled)
        try await XCTAssertEqualAsync(await self.rulesetProvider.saveParamRuleset?.eTag, latestRuleset.eTag)
    }

    func testDownloadRulesetFails() async throws {
        let ruleset = Ruleset(id: "Asimov", type: .adBlocking, name: "RulesForRobots", eTag: "tag", lastModified: Date(), size: 1)

        self.mockS3Client.downloadDataForResult = .failure(NSError.some)

        do {
            let _ = try await self.client.getRuleset(ruleset: ruleset)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as NSError, NSError.some)
        }
        
        XCTAssertTrue(self.mockS3Client.downloadDataForCalled)
    }
}


// Error for testing.  We don't care what the error is, just that we can dictate one is returned and it can be compared to what we expect.
extension NSError {
    static var some: NSError {
        return NSError(domain: "NSError", code: 0, userInfo: nil)
    }
}




// To help us create mock AWSS3 objects to return
extension AWSS3Object {
    convenience init(key: String, eTag: String, lastModified: Date, size: Int) {
        self.init()
        self.key = key
        self.eTag = eTag
        self.lastModified = lastModified
        self.size = NSNumber(integerLiteral: size)
    }
}

extension AWSS3ListObjectsV2Output {
    convenience init(contents: [AWSS3Object]) {
        self.init()
        self.contents = contents
    }
}

actor MockRulesetStorageProvider: RulesetStorageProvider {

    var readCalled = false
    var readParamRuleset: Ruleset?
    var _readResult: RulesetData?
    func set(readResult: RulesetData?) {
        _readResult = readResult
    }

    func read(ruleset: Ruleset) -> RulesetData? {
        readCalled = true
        readParamRuleset = ruleset
        return _readResult
    }

    var saveCalled = false
    var saveError: Error?
    var saveParamRuleset: Ruleset?
    var saveParamData: Data?
    func save(ruleset: Ruleset, data: Data) throws {
        saveCalled = true
        saveParamRuleset = ruleset
        saveParamData = data
        if let e = saveError {
            throw e
        }
    }

    var resetCalled = false
    func reset() throws {
        resetCalled = true
    }
}

actor MockExceptionProvider: ExceptionProvider {
    var getCalled = false
    var getExceptionResult: [BlockingException] = []
    func get() -> [BlockingException] {
        getCalled = true
        return getExceptionResult
    }
    
    var addCalled = false
    func add(_ exceptions: [BlockingException]) {
        addCalled = true
    }
    
    var removeCalled = false
    func remove(_ exceptions: [BlockingException]) {
        removeCalled = true
    }
    
    var removeAllCalled = false
    func removeAll() {
        removeAllCalled = true
    }
}
