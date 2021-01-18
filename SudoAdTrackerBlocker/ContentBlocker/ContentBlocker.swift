//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Represents a base ruleset combined with a list of exceptions.
public struct ContentBlocker {

    /// Generated ID of this content blocker. Based on the base ruleset and an exceptions added.
    public let id: String

    /// The base ruleset used to generate the content blocking json
    public let baseRuleset: Ruleset

    /// The content blocking json in Apples content blocking format.  This can be passed to either a content blocking extension or Webkit for blocking.
    public let rulesetData: String

    /// Exceptions applied to the content blocker.
    public let exceptions: [BlockingException]

    internal init(id: String, baseRuleset: Ruleset, rulesetData: String, exceptions: [BlockingException]) {
        self.id = id
        self.baseRuleset = baseRuleset
        self.rulesetData = rulesetData
        self.exceptions = exceptions
    }
}

