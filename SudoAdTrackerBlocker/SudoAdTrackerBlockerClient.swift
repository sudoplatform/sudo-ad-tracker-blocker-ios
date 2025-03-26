//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import AWSS3
import SudoUser
import SudoLogging

/// Safari only lets us do host exceptions due to the restricted use of `if-domain` and `if-top-url`.
/// So a `BlockingException` on iOS is a simple string.
/// See https://developer.apple.com/documentation/safariservices/creating_a_content_blocker.
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

    // MARK: - Properties: Public

    public let config: SudoAdTrackerBlockerConfig

    // MARK: - Properties: Internal

    lazy var rulesetDownloadTasks = RulesetDownloadTasks()

    let storageProvider: RulesetStorageProvider

    let s3Client: S3Client

    let exceptionProvider: ExceptionProvider

    let logger: SudoLogging.Logger

    // MARK: - Lifecycle

    public init(config: SudoAdTrackerBlockerConfig, logger: Logger? = nil) throws {
        self.logger = logger ?? Logger.shared
        self.config = config
        self.s3Client = try DefaultS3Client(region: config.region, bucket: config.bucket, logger: self.logger)
        storageProvider = FileSystemRulesetStorageProvider()
        exceptionProvider = DefaultExceptionProvider()
    }

    init(
        config: SudoAdTrackerBlockerConfig,
        storageProvider: RulesetStorageProvider,
        s3Client: S3Client,
        exceptionProvider: ExceptionProvider,
        logger: Logger? = nil
    ) {
        self.config = config
        self.storageProvider = storageProvider
        self.s3Client = s3Client
        self.exceptionProvider = exceptionProvider
        self.logger = logger ?? Logger.shared
    }

    // MARK: - Conformance: SudoAdTrackerBlockerClient

    public func listRulesets() async throws -> [Ruleset] {
        let items = try await s3Client.listAllItems()
        let ruleSets = items.compactMap(RulesetTransformer.transformRulesetItem)
        return ruleSets
    }

     public func getRuleset(ruleset: Ruleset) async throws -> Data {
        if let cachedRuleset = await storageProvider.read(ruleset: ruleset), cachedRuleset.meta.eTag == ruleset.eTag {
            logger.debug("Found cached ruleset for \(ruleset.id), skipping download")
            return cachedRuleset.data
        } else {
            logger.debug("No cached ruleset for \(ruleset.id) found, fetching from service")
            return try await downloadDataFor(ruleset: ruleset)
        }
    }

    public func getContentBlocker(ruleset: Ruleset) async throws -> ContentBlocker {
        let rulesetData = try await getRuleset(ruleset: ruleset)
        let builder = ContentBlockerBuilder(rulesetData: RulesetData(meta: ruleset, data: rulesetData))
        guard let contentBlocker = builder.buildWithExceptions(exceptions: await getExceptions()) else {
            throw AdTrackerBlockerError.failedToDecodeRuleListData
        }
        return contentBlocker
    }

    public func getExceptions() async -> [BlockingException] {
        return await exceptionProvider.get()
    }

    public func addExceptions(_ exceptions: [BlockingException]) async {
        await exceptionProvider.add(exceptions)
    }

    public func removeExceptions(_ exceptions: [BlockingException]) async {
        await exceptionProvider.remove(exceptions)
    }

    public func removeAllExceptions() async {
        await exceptionProvider.removeAll()
    }

    public func reset() async throws {
        try await storageProvider.reset()
        await exceptionProvider.removeAll()
    }

    // MARK: - Helpers

    func downloadDataFor(ruleset: Ruleset) async throws -> Data {
        // Is this ruleset already being downloaded? if so await the result
        if let existingTask = await rulesetDownloadTasks.taskFor(ruleset: ruleset) {
            return try await existingTask.value
        }

        // Create a download task
        let downloadTask: Task<Data, Error> = Task {
            let data = try await s3Client.download(key: ruleset.id)
            return data
        }

        // cache the download task in our container
        await rulesetDownloadTasks.addDownloadTask(ruleset: ruleset, task: downloadTask)

        do {
            // await the result
            let data = try await downloadTask.value

            // cached data in storage provider.
            try await storageProvider.save(ruleset: ruleset, data: data)

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
}

actor RulesetDownloadTasks {

    var downloadTasks: [String: Task<Data, Error>] = [:]

    func addDownloadTask(ruleset: Ruleset, task: Task<Data, Error>) {
        downloadTasks[ruleset.id] = task
    }

    func removeTaskFor(ruleset: Ruleset) {
        downloadTasks[ruleset.id] = nil
    }

    func taskFor(ruleset: Ruleset) -> Task<Data, Error>? {
        return downloadTasks[ruleset.id]
    }
}
