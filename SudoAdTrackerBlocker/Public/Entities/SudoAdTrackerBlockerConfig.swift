//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import AWSS3
import SudoUser
import SudoConfigManager

/// Configuration object for ad tracker blocker.
public class SudoAdTrackerBlockerConfig {

    // MARK: - Supplementary

    public enum ConfigError: Error {
        case missingKey
        case failedToReadConfigurationFile
    }

    // MARK: - Properties

    public let region: String

    public let poolId: String

    public let identityPoolId: String

    public let bucket: String

    // MARK: - Lifecycle

    /// Creates a config specifying all the required parameters. Most useful for testing
    public init(region: String, poolId: String, identityPoolId: String, bucket: String) {
        self.region = region
        self.poolId = poolId
        self.identityPoolId = identityPoolId
        self.bucket = bucket
    }

    /// Creates a config by reading values from SudoConfigManager.
    /// - Parameter configManager: The manager responsible for fetching config sets.
    public init(configManager: SudoConfigManager) throws {
        guard let identityConfig = configManager.getConfigSet(namespace: "identityService") else {
            throw ConfigError.missingKey
        }
        guard let siteReputationService = configManager.getConfigSet(namespace: "adTrackerBlockerService") else {
            throw ConfigError.missingKey
        }
        guard
            let region = siteReputationService["region"] as? String,
            let poolId = identityConfig["poolId"] as? String,
            let identityPoolId = identityConfig["identityPoolId"] as? String,
            let staticDataBucket = siteReputationService["bucket"] as? String
        else {
            throw ConfigError.missingKey
        }
        self.region = region
        self.poolId = poolId
        self.identityPoolId = identityPoolId
        self.bucket = staticDataBucket
    }

    /// Creates a config by reading a config file through SudoConfigManager.  This is the recommended approach to
    /// pull config parameters from the config file downloaded through the admin console.
    public convenience init() throws {
        let defaultConfigManagerName = SudoConfigManagerFactory.Constants.defaultConfigManagerName
        guard let configManager = SudoConfigManagerFactory.instance.getConfigManager(name: defaultConfigManagerName) else {
            throw ConfigError.failedToReadConfigurationFile
        }
        try self.init(configManager: configManager)
    }
}
