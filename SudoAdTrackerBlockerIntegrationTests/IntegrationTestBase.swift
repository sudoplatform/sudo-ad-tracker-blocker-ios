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

/// Allows a string to be an error for test purposes and makes it simpler to say "something isn't right".
extension String: LocalizedError {
    public var errorDescription: String? { return self }
}

/// Base integration test that handles setup, registration, and degregistration of sudo user so
/// integration tests that require authentication can run.
class IntegrationTestBase: XCTestCase {

    var userClient: SudoUserClient!
    
    override func setUp() async throws {
        // Initialize the client.
        let namespace = "atb-integration-test"
        self.userClient = try DefaultSudoUserClient(keyNamespace: namespace)
        try await userClient.reset()
        
        let isRegistered = try await userClient.isRegistered()
        XCTAssertFalse(isRegistered)
        
        try await register(userClient: userClient)
        try await signIn(userClient: userClient)
    }
    
    override func tearDown() async throws {
        try await deregister(userClient: userClient)
        try await userClient.reset()
    }
    
    func loadFile(name: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: nil) else {
            return nil
        }
        return try? String(contentsOf: url)
    }
    
    func readKeys() -> (testKey: String, testKeyId: String)? {
        guard let testKey = loadFile(name: "register_key.private") ?? ProcessInfo.processInfo.environment["REGISTER_KEY"] else {
            XCTFail("REGISTER_KEY environment variable not set or register_key.private file not found.")
            return nil
        }

        guard let testKeyId = loadFile(name: "register_key.id") ?? ProcessInfo.processInfo.environment["REGISTER_KEY_ID"] else {
            XCTFail("Failed to read TEST key ID from file: register_key.id")
            return nil
        }
        
        return (testKey, testKeyId)
    }

    private func register(userClient: SudoUserClient) async throws {
        guard let keys = readKeys() else {
            let message = "Missing register_key.private or register_key.id. Please make sure these files are present in ${PROJECT_DIR}/config and are copied to the testing bundle."
            throw message
        }

        let keyManager = LegacySudoKeyManager(serviceName: "com.sudoplatform.appservicename",
                                              keyTag: "com.sudoplatform",
                                              namespace: "test")
        let authProvider = try TESTAuthenticationProvider(name: "testRegisterAudience",
                                                          key: keys.testKey,
                                                          keyId: keys.testKeyId,
                                                          keyManager: keyManager)
        _ = try await userClient.registerWithAuthenticationProvider(authenticationProvider: authProvider,
                                                                    registrationId: "srs-int-test-\(Date())")
    }

    private func signIn(userClient: SudoUserClient) async throws {
        do {
            _ = try await userClient.signInWithKey()
        } catch {
            print("warning: Failed to signIn: \(error)")
        }
    }

    private func deregister(userClient: SudoUserClient) async throws {
        do {
            _ = try await userClient.deregister()
        } catch {
            print("warning: Failed to deregister: \(error)")
        }
    }
}
