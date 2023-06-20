//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import SudoAdTrackerBlocker
import AWSS3

import AWSAppSync
import SudoLogging
import SudoKeyManager
import SudoUser
import SudoConfigManager
import WebKit

extension String: Error {}

class SudoAdTrackerBlockerIntegrationTests: XCTestCase {

    var sudoUserHelper: SudoUserTestHelper!
    var client: SudoAdTrackerBlockerClient!
    var store: WKContentRuleListStore!

    override func setUpWithError() throws {
        let e = expectation(description: "")
        try self.sudoUserHelper = SudoUserTestHelper()
        let clientConfig = try SudoAdTrackerBlockerConfig(userClient: self.sudoUserHelper.sudoUserClient)
        self.client = DefaultSudoAdTrackerBlockerClient(config: clientConfig)

        Task {
            try await self.client.reset()
            e.fulfill()
        }

        let storeURL = FileManager.default.temporaryDirectory
        self.store = WKContentRuleListStore.init(url: storeURL)

        self.waitForExpectations(timeout: 10)
    }

    override func tearDownWithError() throws {
        if self.testRun?.hasBeenSkipped == true {
            XCTFail()
            return
        }
        let e = expectation(description: "")
        Task {
            try await self.sudoUserHelper.deregister()
            try await self.client.reset()
            e.fulfill()
        }
        self.waitForExpectations(timeout: 10)
    }

    /// Tests that we can list the rulesets and that a ruleset can be compiled
    func testListAndCompileRulesets() async throws {
        try await self.sudoUserHelper.registerAndSignIn()
        
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

import SudoUser
import SudoKeyManager
/// To help setup a SudoUserClient instance to be used for integration tests.
/// Takes care of loading config files, keys, client setup, and signin/register.
/// The goal of this class is so we can setup integration tests with one line of code.
///
/// This assumes the following setup works has been done:
///
/// 1: Integration test target needs a test host in order to use the keychain.
///
/// To setup a test host, Add a new target to the project and choose "App" as the type.
/// Then setup keychain sharing by choosing "Signing and Capabilities" for the target and add the keychain sharing capability.
/// Finally add a keychain sharing group, any will do.
///
/// 2: Copy config.
///
/// The config files from the platform dashboard need to be copied to the bundle.
/// This is the same for all platform projects and the config needs to be copied for each target.
///
///
/// 3: Provide registration keys:
///
///     a: Provide anonyome_ssm_parameter_register_key.json file. In other projects this is typically in a folder
/// in the root directory named something like `$(project_name)-system-test-config` and is applicable for CI
///
///     b: Provide register_key.private and register_key.id.  Quickest way to get setup locally.
///
///
class SudoUserTestHelper {

    let testAuthenticationProvider: TESTAuthenticationProvider
    let sudoUserClient: SudoUserClient
    let keyManager: SudoKeyManager

    init() throws {
        let SudoUserClient = try DefaultSudoUserClient(keyNamespace: "ids")
        self.sudoUserClient = SudoUserClient
        // Create a key manager to be used by the test authentication provider.
        let authProviderKeyManager = LegacySudoKeyManager(
            serviceName: "com.sudoplatform.appservicename",
            keyTag: "com.sudoplatform",
            namespace: "test"
        )
        
        keyManager = authProviderKeyManager

        let bundle = Bundle(for: type(of: self))
        if let testKeyPath = bundle.path(forResource: "register_key", ofType: "private"),
           let testKeyIdPath = bundle.path(forResource: "register_key", ofType: "id") {
            var testKey = try String(contentsOfFile: testKeyPath)
            
            let testKeyId = try String(contentsOfFile: testKeyIdPath).trimmingCharacters(in: .whitespacesAndNewlines)

            NSLog("Registering with test key id: \(testKeyId)")
            NSLog("Registering with test key: \(testKey)")
            
            // CI has had a key with spaces in it that appears valid for other platforms.
            // We can cope with this here for a quick fix.
            testKey = testKey.replacingOccurrences(of: "-----BEGIN RSA PRIVATE KEY-----", with: "")
            testKey = testKey.replacingOccurrences(of: "-----END RSA PRIVATE KEY-----", with: "")
            testKey = testKey.replacingOccurrences(of: " ", with: "")
            testKey = testKey.replacingOccurrences(of: "\n", with: "")
            
            self.testAuthenticationProvider = try TESTAuthenticationProvider(
                name: "testRegisterAudience",
                key: testKey,
                keyId: testKeyId,
                keyManager: authProviderKeyManager)
        }
        else {
            throw NSError(domain: "SudoUserTestHelper", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing register_key.private and register_key.id.  Please make sure the correct files are copied to the testing bundle"])
        }
    }

    func reset() async throws {
        try await self.sudoUserClient.reset()
        self.testAuthenticationProvider.reset()
        try keyManager.removeAllKeys()
    }

    // If registered, then deregister and then reset
    func deregister() async throws {
        if try await self.sudoUserClient.isRegistered() {
            _ = try await self.sudoUserClient.deregister()
        }
        try await self.sudoUserClient.reset()
        try keyManager.removeAllKeys()
    }

    // If not registered, then register
    func register() async throws {
        if try await !self.sudoUserClient.isRegistered() {
            _ = try await self.sudoUserClient.registerWithAuthenticationProvider(authenticationProvider: self.testAuthenticationProvider, registrationId: "dummy_rid")
        }
    }

    func signIn() async throws {
        _ = try await self.sudoUserClient.signInWithKey()
    }

    func registerAndSignIn() async throws {
        try await self.register()
        try await self.signIn()
    }
}

