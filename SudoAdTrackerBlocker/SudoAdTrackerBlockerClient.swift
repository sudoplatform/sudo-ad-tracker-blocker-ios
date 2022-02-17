//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import AWSS3
import SudoUser
import SudoLogging

// Safari only lets us do host exceptions due to the restricted use of `if-domain` and `if-top-url`.
// So a `BlockingException` on iOS is a simple string.
// See https://developer.apple.com/documentation/safariservices/creating_a_content_blocker.
public typealias BlockingException = String

public protocol SudoAdTrackerBlockerClient {

    /// Lists all available RuleSets and their metadata.
    /// Like a command line "ls" command
    ///   - Parameters:
    ///     - returns: List of available rulesets
    func listRulesets() async throws -> [Ruleset]

    /// Fetches the base ruleset data from the service.
    /// - Parameters:
    ///   - ruleset: Ruleset to fetch
    ///   - returns: Ruleset Data when available. Ruleset contents are cached for performance.
    func getRuleset(ruleset: Ruleset) async throws -> Data

    /// Generates a content blocker ruleset from the base provided by the service combined with
    /// exceptions added to the client.
    /// - Parameters:
    ///   - ruleset: The ruleset to fetch and apply
    ///   - returns: Content Blocker when available
    func getContentBlocker(ruleset: Ruleset) async throws -> ContentBlocker

    /// Get all exceptions that have been added.
    func getExceptions() async -> [BlockingException]

    /// Add new exceptions
    /// - Parameter exceptions: The exceptions to add
    func addExceptions(_ exceptions: [BlockingException]) async

    /// Removes exceptions
    /// - Parameter exceptions: The exceptions to remove
    func removeExceptions(_ exceptions: [BlockingException]) async

    /// Removes all exceptions
    func removeAllExceptions() async

    /// Resets any cached data and exceptions
    func reset() async throws
}

enum AdTrackerBlockerError: Error {
    case failedToDecodeRuleListData
}

public class DefaultSudoAdTrackerBlockerClient: SudoAdTrackerBlockerClient {

    public let config: SudoAdTrackerBlockerConfig
    let storageProvider: RulesetStorageProvider
    let s3Client: S3Client
    private let exceptionProvider: ExceptionProvider

    public init(config: SudoAdTrackerBlockerConfig) {
        self.config = config
        self.s3Client = DefaultS3Client(awsServiceConfig: config.awsServiceConfig)
        storageProvider = FileSystemRulesetStorageProvider()
        exceptionProvider = DefaultExceptionProvider()
    }

    internal init(config: SudoAdTrackerBlockerConfig, storageProvider: RulesetStorageProvider, s3Client: S3Client, exceptionProvider: ExceptionProvider) {
        self.config = config
        self.storageProvider = storageProvider
        self.s3Client = s3Client
        self.exceptionProvider = exceptionProvider
    }
    
    /// Lists rulesets provided by the service.
    /// - Parameter returns: List of rulesets to be called when data is available.
    public func listRulesets() async throws -> [Ruleset] {
        let output = try await s3Client.listObjectsV2In(bucket: config.bucket)
        return output.contents?.compactMap({ Ruleset(s3Object: $0)}) ?? []
    }

    /// Fetches the base ruleset data from the service.
    /// - Parameters:
    ///   - ruleset: Ruleset to fetch
    ///   - return: Ruleset Data
    ///   - throws: When no data is cached and downloading fails.
     public func getRuleset(ruleset: Ruleset) async throws -> Data {
        if let cachedRuleset = await storageProvider.read(ruleset: ruleset), cachedRuleset.meta.eTag == ruleset.eTag {
            Logger.shared.debug("Found cached ruleset for \(ruleset.id), skipping download")
            return cachedRuleset.data
        } else {
            Logger.shared.debug("No cached ruleset for \(ruleset.id) found, fetching from service")
            return try await downloadDataFor(ruleset: ruleset)
        }
    }

    /// Generates a content blocker ruleset from the base provided by the service combined with
    /// exceptions added to the client.
    /// - Parameters:
    ///   - ruleset: The base ruleset from the service
    ///   - returns: Content Blocker when available
    ///   - Throws: When no rulesets are retrieved or when the builder fails to build the blocker.
    public func getContentBlocker(ruleset: Ruleset) async throws -> ContentBlocker {
        let rulesetData = try await getRuleset(ruleset: ruleset)
        let builder = ContentBlockerBuilder(rulesetData: RulesetData(meta: ruleset, data: rulesetData))
        guard let contentBlocker = builder.buildWithExceptions(exceptions: await self.getExceptions()) else {
            throw AdTrackerBlockerError.failedToDecodeRuleListData
        }
        return contentBlocker
    }

    /// Downloads the ruleset from S3. If download succeeds the ruleset is saved to disk.
    lazy var rulesetDownloadTasks: RulesetDownloadTasks = { return .init() }()
    private func downloadDataFor(ruleset: Ruleset) async throws -> Data {
        // Is this ruleset already being downloaded? if so await the result
        if let existingTask = await rulesetDownloadTasks.taskFor(ruleset: ruleset) {
            return try await existingTask.value
        }

        // Create a download task
        let downloadTask: Task<Data, Error> = Task {
            let data = try await s3Client.downloadDataFor(ruleset: ruleset, inBucket: config.bucket)
            return data
        }

        // cache the download task in our container
        await rulesetDownloadTasks.addDownloadTask(ruleset: ruleset, task: downloadTask)

        do {
            // await the result
            let data = try await downloadTask.value

            // cached data in storage provider.
            try await self.storageProvider.save(ruleset: ruleset, data: data)

            // remove cached task
            await rulesetDownloadTasks.removeTaskFor(ruleset: ruleset)

            return data
        } catch {
            // on error remove cached task.
            await rulesetDownloadTasks.removeTaskFor(ruleset: ruleset)
            // re-throw error.
            throw error
        }
    }

    /// Get all exceptions that have been added.
    public func getExceptions() async -> [BlockingException] {
        return await self.exceptionProvider.get()
    }

    /// Add new exceptions
    /// - Parameter exceptions: The exceptions to add
    public func addExceptions(_ exceptions: [BlockingException]) async {
        await self.exceptionProvider.add(exceptions)
    }

    /// Removes exceptions
    /// - Parameter exceptions: The exceptions to remove
    public func removeExceptions(_ exceptions: [BlockingException]) async {
        await self.exceptionProvider.remove(exceptions)
    }

    /// Removes all exceptions
    public func removeAllExceptions() async {
        await self.exceptionProvider.removeAll()
    }

    public func reset() async throws {
        try await self.storageProvider.reset()
        await self.exceptionProvider.removeAll()
    }
}

actor RulesetDownloadTasks {
    var downloadTasks: [String: Task<Data, Error>] = [:]

    func addDownloadTask(ruleset: Ruleset, task: Task<Data, Error>) {
        self.downloadTasks[ruleset.id] = task
    }

    func removeTaskFor(ruleset: Ruleset) {
        self.downloadTasks[ruleset.id] = nil
    }

    func taskFor(ruleset: Ruleset) -> Task<Data, Error>? {
        return self.downloadTasks[ruleset.id]
    }
}
