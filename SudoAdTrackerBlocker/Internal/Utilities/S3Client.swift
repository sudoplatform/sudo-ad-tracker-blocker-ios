//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Amplify
import AWSS3StoragePlugin
import Foundation
import SudoLogging

/// Client to interact with S3
protocol S3Client {

    /// List files in the S3 bucket
    func listAllItems() async throws -> [StorageListResult.Item]

    /// Downloads the ruleset from the S3 bucket
    func download(key: String) async throws -> Data
}

class DefaultS3Client: S3Client {

    // MARK: - Properties

    /// Lists formatted for Apple platforms have an "apple" path in the key. The entire prefix needs to be specified to get filtering support from S3.
    var bucketPrefixFilter: String? = "/filter-lists/apple"
    
    /// The Amplify storage plugin used to list item keys and download items.
    let storagePlugin: AWSS3StoragePlugin
    
    /// A logging instance.
    let logger: SudoLogging.Logger

    // MARK: - Lifecycle

    /// Initializes a `DefaultS3Client`.
    /// - Parameters:
    ///   - region: The AWS region.
    ///   - bucket: The S3 storage bucket.
    init(region: String, bucket: String, logger: SudoLogging.Logger) throws {
        self.logger = logger
        let storageConfig: [String: String] = [
            "region": region,
            "bucket": bucket,
            "defaultAccessLevel": "private"
        ]
        let config = JSONValue.object(storageConfig.mapValues(JSONValue.string))
        storagePlugin = AWSS3StoragePlugin()
        try storagePlugin.configure(using: config)
    }

    func listAllItems() async throws -> [StorageListResult.Item] {
        do {
            let options = StorageListRequest.Options(path: "/filter-lists/apple")
            let listResult = try await storagePlugin.list(options: options)
            return listResult.items
        } catch {
            throw error
        }
    }

    func download(key: String) async throws -> Data {
        do {
            let downloadTask = storagePlugin.downloadData(key: key, options: nil)
            await downloadTask.progress.forEach { progress in
                logger.debug("Downloading \(key): \(Int(progress.fractionCompleted * 100))% complete.")
            }
            return try await downloadTask.value
        } catch {
            throw error
        }
    }
}
