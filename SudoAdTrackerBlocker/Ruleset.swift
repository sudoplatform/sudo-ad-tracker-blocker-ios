//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import AWSS3

public enum RulesetType: String, Codable {
    case adBlocking = "AD"
    case privacy = "PRIVACY"
    case social = "SOCIAL"
    case unknown = "UNKNOWN"
}

public struct Ruleset: Codable {

    public let id: String
    public let type: RulesetType
    public let name: String
    public let eTag: String
    public let lastModified: Date
    public let size: Int

    /// Creates a ruleset
    /// - Parameters:
    ///   - id: id of the ruleset
    ///   - type: ruleset type
    ///   - name: name
    ///   - eTag: eTag
    ///   - lastModified: date last modified
    ///   - size: Size of file in bytes
    public init(id: String, type: RulesetType, name: String, eTag: String, lastModified: Date, size: Int) {
        self.id = id
        self.type = type
        self.name = name
        self.eTag = eTag
        self.lastModified = lastModified
        self.size = size
    }


    /// Used to transform a file in the S3 bucket to a ruleset.
    init?(s3Object: AWSS3Object) {
        guard let etag = s3Object.eTag,
              let key = s3Object.key,
              let lastModified = s3Object.lastModified,
              let size = s3Object.size?.intValue else {
            return nil
        }

        guard let (rawType, name) = Self.typeAndListNameFrom(key: key) else {
            return nil
        }

        self.id = key
        self.type = RulesetType(rawValue: rawType) ?? RulesetType.unknown
        self.name = name
        self.eTag = etag
        self.lastModified = lastModified
        self.size = size
    }

    /// Parse the name and raw type string from the aws key
    /// These are expected to be in the form "/ad-tracker-blocker/filter-lists/adblock-plus/AD/easylist.txt"
    static func typeAndListNameFrom(key: String) -> (type: String, name: String)? {
        guard let url = URL(string: key) else { return nil }
        guard url.pathComponents.count >= 2 else { return nil }
        let name = url.deletingPathExtension().lastPathComponent
        let type = url.deletingLastPathComponent().lastPathComponent
        return (type: type, name: name)
    }
}
