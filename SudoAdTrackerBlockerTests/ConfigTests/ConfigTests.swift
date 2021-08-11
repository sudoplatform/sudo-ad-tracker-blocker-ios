//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import SudoAdTrackerBlocker
import SudoUser
import SudoConfigManager
import AWSS3

// so we can throw errors like `throw "foobar failed"`
extension String: Error {}

class ConfigTests: XCTestCase {

    var config: [String: Any]!
    var configManager: SudoConfigManager!
    var instanceUnderTest: SudoAdTrackerBlockerConfig!

    override func setUpWithError() throws {

        guard let configPath = Bundle(for: Self.self).url(forResource: "testConfig", withExtension: "json") else {
            throw "TestConfigNotFound"
        }

        let jsonData = try Data(contentsOf: configPath)

        guard let json = try JSONSerialization.jsonObject(with: jsonData, options: .init()) as? [String: Any] else {
            throw "Invalid test config file format"
        }

        config = json
        configManager = DefaultSudoConfigManager(logger: nil, config: config)
        let userClient = MockSudoUserClient()
        instanceUnderTest = try SudoAdTrackerBlockerConfig(
            userClient: userClient,
            config: configManager
        )
    }

    func test_config_loads_expected_values() {
        XCTAssertEqual(instanceUnderTest.region, "us-east-1")
        XCTAssertEqual(instanceUnderTest.poolId, "us-east-1_XmpKiaLzp")
        XCTAssertEqual(instanceUnderTest.identityPoolId, "us-east-1:f1052db1-2243-4070-bf31-0658c06cf986")
        XCTAssertEqual(instanceUnderTest.regionType, AWSRegionType.USEast1)
        XCTAssertEqual(instanceUnderTest.bucket, "atb-s3-sbt-dev-static0r0a0bucketebb21caf-1niqbifrp2fvl")
    }
}
