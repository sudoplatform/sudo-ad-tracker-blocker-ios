//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import SudoLogging

/// Handles storage of cached rulesets
protocol RulesetStorageProvider: Actor {
    func read(ruleset: Ruleset) -> RulesetData?

    func save(ruleset: Ruleset, data: Data) throws

    func reset() throws
}

/// Representation of an a ruleset with the associated data
struct RulesetData: Codable {
    let meta: Ruleset
    let data: Data
}

/// Handles caching of rulesets originating from S3.  By default will store files in ~/cache/Rulesets.
/// Each ruleset file is stored with the metadata from S3 along with the files data.
actor FileSystemRulesetStorageProvider: RulesetStorageProvider {

    var fileManager: FileManager
    let baseStoragePath: URL

    // Encoder/Decoder to read and write the rule list file format.
    lazy var decoder: JSONDecoder = {
        return JSONDecoder()
    }()

    lazy var encoder: JSONEncoder = {
        return JSONEncoder()
    }()

    init(storageURL: URL? = nil) {
        let fileManager = FileManager.default
        self.fileManager = fileManager
        let baseStoragePath = (storageURL ?? fileManager.cachesDirectory).appendingPathComponent("Rulesets")

        // Create the storage directory first.  Writes will fail if the directory doesn't exist.
        if !fileManager.fileExists(atPath: baseStoragePath.path) {
            do {
                try fileManager.createDirectory(at: baseStoragePath, withIntermediateDirectories: false, attributes: nil)
            } catch {
                Logger.shared.debug("Failed to create rulesets cache directory: \(baseStoragePath). \(error)")
            }
        }

        self.baseStoragePath = baseStoragePath
    }

    func read(ruleset: Ruleset) -> RulesetData? {
        let rulesetURL = self.urlFor(ruleset: ruleset)
        guard let data = try? Data(contentsOf: rulesetURL), let rulesetData = try? decoder.decode(RulesetData.self, from: data) else {
            return nil
        }
        return rulesetData
    }

    func save(ruleset: Ruleset, data: Data) throws {
        let dataToWrite = try encoder.encode(RulesetData(meta: ruleset, data: data))
        try dataToWrite.write(to: self.urlFor(ruleset: ruleset))
    }

    func reset() throws {
        let files = try fileManager.contentsOfDirectory(at: self.baseStoragePath, includingPropertiesForKeys: nil, options: .init())
        try files.forEach { (url) in
            try fileManager.removeItem(at: url)
        }
    }

    private func urlFor(ruleset: Ruleset) -> URL {
        return baseStoragePath.appendingPathComponent(ruleset.name)
    }
}
