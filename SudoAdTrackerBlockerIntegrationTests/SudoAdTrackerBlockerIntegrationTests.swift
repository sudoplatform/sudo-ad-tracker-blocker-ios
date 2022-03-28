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

class SudoAdTrackerBlockerIntegrationTests: XCTestCase {

    var sudoUserHelper: SudoUserTestHelper!
    var client: SudoAdTrackerBlockerClient!
    var store: WKContentRuleListStore!

    override func setUpWithError() throws {
        try self.sudoUserHelper = SudoUserTestHelper()
        let clientConfig = try SudoAdTrackerBlockerConfig(userClient: self.sudoUserHelper.sudoUserClient)
        self.client = DefaultSudoAdTrackerBlockerClient(config: clientConfig)
        try self.client.reset()

        let storeURL = FileManager.default.temporaryDirectory
        self.store = WKContentRuleListStore.init(url: storeURL)
    }

    override func tearDownWithError() throws {
        if self.testRun?.hasBeenSkipped == true {
            XCTFail()
            return
        }
        try self.sudoUserHelper.deregister()
        try self.client.reset()
    }

    /// Tests that we can list the rulesets and that a ruleset can be compiled
    func testListAndCompileRulesets() throws {
        try self.sudoUserHelper.registerAndSignIn()

        let listExpectation = self.expectation(description: "Waiting for list rulesets")
        self.client.listRulesets { result in
            switch result {
            case .success(let rulesets):
                XCTAssertGreaterThan(rulesets.count , 0)
                guard let easyprivacy = rulesets.filter({$0.name.contains("easyprivacy")}).first else {
                    XCTFail("easyprivacy not found, cannot test list compilation.")
                    return
                }
                self.testContentBlockerCompiles(ruleset: easyprivacy) {
                    listExpectation.fulfill()
                }
            case .failure(let error):
                XCTFail("List failed with error: \(error)")
                listExpectation.fulfill()
            }
        }

        self.waitForExpectations(timeout: 60*5, handler: nil)
    }

    func testContentBlockerCompiles(ruleset: Ruleset, completion: @escaping () -> Void) {
        self.client.getContentBlocker(ruleset: ruleset) { (result) in
            guard let blocker = try? result.get() else {
                XCTFail()
                completion()
                return
            }
            DispatchQueue.main.async {
                self.store.compileContentRuleList(forIdentifier: blocker.id, encodedContentRuleList: blocker.rulesetData, completionHandler: { (list, error) in
                    XCTAssertNil(error)
                    completion()
                })
            }
        }
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

    init() throws {
        let SudoUserClient = try DefaultSudoUserClient(keyNamespace: "ids")
        self.sudoUserClient = SudoUserClient

        try self.sudoUserClient.reset()

        // Create a key manager to be used by the test authentication provider.
        let authProviderKeyManager = SudoKeyManagerImpl(
            serviceName: "com.sudoplatform.appservicename",
            keyTag: "com.sudoplatform",
            namespace: "test"
        )

        let bundle = Bundle(for: type(of: self))
        if let testKeyPath = bundle.path(forResource: "register_key", ofType: "private"),
           let testKeyIdPath = bundle.path(forResource: "register_key", ofType: "id") {
            let testKey = try String(contentsOfFile: testKeyPath)
            let testKeyId = try String(contentsOfFile: testKeyIdPath).trimmingCharacters(in: .whitespacesAndNewlines)

            NSLog("Registering with test key id: \(testKeyId)")
            NSLog("Registering with test key: \(testKey)")

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

    deinit {
        self.reset()
    }

    func reset() {
        do {
            try self.sudoUserClient.reset()
        }
        catch {
            print("Failed to reset sudo user client: \(error)")
        }
    }

    func deregister(timeout: Int = 20) throws {

        guard self.sudoUserClient.isRegistered() else {
            return
        }

        let group = DispatchGroup()
        var deregisterError: Error?
        group.enter()
        try self.sudoUserClient.deregister { (result) in
            switch result {
            case .success:
                break
            case let .failure(cause):
                deregisterError = cause
            }
            group.leave()
        }

        if group.wait(timeout: DispatchTime.now() + .seconds(timeout)) == .success {
            try self.sudoUserClient.reset()
            if let error = deregisterError {
                throw error
            }
        }
        else {
            try self.sudoUserClient.reset()
            throw NSError(domain: "SudoUserTestHelper", code: 0, userInfo: [NSLocalizedDescriptionKey: "De-register timeout exceeded"])
        }
    }

    func register(timeout: Int = 20) throws {
        guard !self.sudoUserClient.isRegistered() else {
            return
        }

        let group = DispatchGroup()
        var registerError: Error?
        group.enter()
        try self.sudoUserClient.registerWithAuthenticationProvider(authenticationProvider: self.testAuthenticationProvider, registrationId: "dummy_rid") { (result) in
            if case .failure(let error) = result {
                registerError = error
            }
            group.leave()
        }

        if group.wait(timeout: DispatchTime.now() + .seconds(timeout)) == .success {
            if let error = registerError {
                throw error
            }
        }
        else {
            throw NSError(domain: "SudoUserTestHelper", code: 0, userInfo: [NSLocalizedDescriptionKey: "Register timeout exceeded"])
        }
    }

    func signIn(timeout: Int = 20) throws {
        try self.register()

        let group = DispatchGroup()
        var signInError: Error?
        group.enter()

        try self.sudoUserClient.signInWithKey { (result) in
            if case .failure(let error) = result {
                signInError = error
            }
            group.leave()
        }

        if group.wait(timeout: DispatchTime.now() + .seconds(timeout)) == .success {
            if let error = signInError {
                throw error
            }
        }
        else {
            throw NSError(domain: "SudoUserTestHelper", code: 0, userInfo: [NSLocalizedDescriptionKey: "Signin timeout exceeded"])
        }
    }

    func registerAndSignIn(timeout: Int = 20) throws {
        try self.register()
        try self.signIn()
    }
}

