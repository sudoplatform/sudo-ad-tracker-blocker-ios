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

    public enum ConfigError: Error {
        case missingKey
        case failedToReadConfigurationFile
    }

    public let userClient: SudoUserClient
    public let region: String
    public let poolId: String
    public let identityPoolId: String
    public let regionType: AWSRegionType
    public let bucket: String

    /// Creates a config specifying all the required parameters. Most useful for testing
    public init(userClient: SudoUserClient, region: String, poolId: String, identityPoolId: String, bucket: String) {
        self.userClient = userClient
        self.region = region
        self.poolId = poolId
        self.identityPoolId = identityPoolId
        self.bucket = bucket
        self.regionType = AWSRegionType.regionTypeForString(regionString: region)
    }

    /// Creates a config by reading a config values from SudoConfigManager.
    public init(userClient: SudoUserClient, config: SudoConfigManager) throws {
        self.userClient = userClient

        guard let identityConfig = config.getConfigSet(namespace: "identityService") else {
            throw ConfigError.missingKey
        }

        guard let region = identityConfig["region"] as? String,
              let poolId = identityConfig["poolId"] as? String,
              let identityPoolId = identityConfig["identityPoolId"] as? String,
              let staticDataBucket = identityConfig["staticDataBucket"] as? String else {
            throw ConfigError.missingKey
        }

        self.region = region
        self.poolId = poolId
        self.identityPoolId = identityPoolId
        self.bucket = staticDataBucket
        self.regionType = AWSRegionType.regionTypeForString(regionString: region)
    }

    /// Creates a config by reading a config file through SudoConfigManager.  This is the recommended approach to
    /// pull config parameters from the config file downloaded through the admin console.
    public convenience init(userClient: SudoUserClient) throws {
        guard let sudoConfig = DefaultSudoConfigManager() else {
            throw ConfigError.failedToReadConfigurationFile
        }
        try self.init(userClient: userClient, config: sudoConfig)
    }
}

extension SudoAdTrackerBlockerConfig {
    var awsServiceConfig: AWSServiceConfiguration {
        let identityProviderManager = IdentityProviderManager(client: userClient, region: region, poolId: poolId)
        let credentialsProvider = AWSCognitoCredentialsProvider(regionType: regionType, identityPoolId: identityPoolId, identityProviderManager: identityProviderManager)

        // this constructor always returns a non-nil value
        return AWSServiceConfiguration(region: AWSRegionType.USEast1, credentialsProvider: credentialsProvider)!
    }
}
