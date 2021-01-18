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
    ///
    /// Lists all available RuleSets and their metadata.
    /// Like a command line "ls" command
    ///
    func listRulesets(completion: @escaping (Result<[Ruleset], Error>) -> Void)

    /// Fetches the base ruleset data from the service.
    /// - Parameters:
    ///   - ruleset: Ruleset to fetch
    ///   - completion: Completion handler when the ruleset is available. Ruleset contents are cached for performance.
    func getRuleset(ruleset: Ruleset, completion: @escaping (Result<Data, Error>) -> Void)

    /// Generates a content blocker ruleset from the base provided by the service combined with
    /// exceptions added to the client.
    /// - Parameters:
    ///   - ruleset: The ruleset to fetch and apply
    ///   - completion: completion handler when the content blocker is available.
    func getContentBlocker(ruleset: Ruleset, completion: @escaping (Result<ContentBlocker, Error>) -> Void)

    /// Get all exceptions that have been added.
    func getExceptions() -> [BlockingException]

    /// Add new exceptions
    /// - Parameter exceptions: The exceptions to add
    func addExceptions(_ exceptions: [BlockingException])

    /// Removes exceptions
    /// - Parameter exceptions: The exceptions to remove
    func removeExceptions(_ exceptions: [BlockingException])

    /// Removes all exceptions
    func removeAllExceptions()

    /// Resets any cached data and exceptions
    func reset() throws
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
    /// - Parameter completion: Completion handler to be called when data is available.
    public func listRulesets(completion: @escaping (Result<[Ruleset], Error>) -> Void) {
        // docs say default limit is 1000 records.  As we only intend to host far fewer than that we don't need to deal with fetching more atm.
        s3Client.listObjectsV2In(bucket: config.bucket) { (result) in
            completion(result.map { (output) -> [Ruleset] in
                let meta = output.contents?.compactMap({ Ruleset(s3Object: $0)})
                return meta ?? []
            })
        }
    }

    /// Fetches the base ruleset data from the service.
    /// - Parameters:
    ///   - ruleset: Ruleset to fetch
    ///   - completion: Completion handler when the ruleset is available. Ruleset contents are cached for performance.
    public func getRuleset(ruleset: Ruleset, completion: @escaping (Result<Data, Error>) -> Void) {
        if let cachedRuleset = storageProvider.read(ruleset: ruleset), cachedRuleset.meta.eTag == ruleset.eTag {
            Logger.shared.debug("Found cached ruleset for \(ruleset.id), skipping download")
            completion(.success(cachedRuleset.data))
            return
        } else {
            Logger.shared.debug("No cached ruleset for \(ruleset.id) found, fetching from service.")
            self.downloadDataFor(ruleset: ruleset, completion: completion)
        }
    }

    /// Generates a content blocker ruleset from the base provided by the service combined with
    /// exceptions added to the client.
    /// - Parameters:
    ///   - ruleset: The base ruleset from the service
    ///   - completion: completion handler when the content blocker is available.
    public func getContentBlocker(ruleset: Ruleset, completion: @escaping (Result<ContentBlocker, Error>) -> Void) {
        self.getRuleset(ruleset: ruleset) { (getResult) in
            switch getResult {
            case .success(let data):
                let builder = ContentBlockerBuilder(rulesetData: RulesetData(meta: ruleset, data: data))
                guard let contentBlocker = builder.buildWithExceptions(exceptions: self.getExceptions()) else {
                    completion(.failure(AdTrackerBlockerError.failedToDecodeRuleListData))
                    return
                }
                completion(.success(contentBlocker))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Downloads the ruleset from S3. If download succeeds the ruleset is saved to disk.
    private func downloadDataFor(ruleset: Ruleset, completion: @escaping (Result<Data, Error>) -> Void) {
        self.s3Client.downloadDataFor(ruleset: ruleset, inBucket: config.bucket) { (downloadResult) in
            // on successful download save the ruleset to disk
            if let data = try? downloadResult.get() {
                try? self.storageProvider.save(ruleset: ruleset, data: data)
            }
            completion(downloadResult)
        }
    }

    /// Get all exceptions that have been added.
    public func getExceptions() -> [BlockingException] {
        return self.exceptionProvider.get()
    }

    /// Add new exceptions
    /// - Parameter exceptions: The exceptions to add
    public func addExceptions(_ exceptions: [BlockingException]) {
        self.exceptionProvider.add(exceptions)
    }

    /// Removes exceptions
    /// - Parameter exceptions: The exceptions to remove
    public func removeExceptions(_ exceptions: [BlockingException]) {
        self.exceptionProvider.remove(exceptions)
    }

    /// Removes all exceptions
    public func removeAllExceptions() {
        self.exceptionProvider.removeAll()
    }

    public func reset() throws {
        try self.storageProvider.reset()
        self.exceptionProvider.removeAll()
    }
}
