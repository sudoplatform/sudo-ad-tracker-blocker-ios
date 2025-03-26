//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

public enum RulesetType: String, Codable {
    case adBlocking = "AD"
    case privacy = "PRIVACY"
    case social = "SOCIAL"
    case unknown = "UNKNOWN"
}

public struct Ruleset: Codable {

    // MARK: - Properties

    public let id: String

    public let type: RulesetType

    public let name: String

    public let eTag: String

    public let lastModified: Date

    public let size: Int

    // MARK: - Lifecycle

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
}
