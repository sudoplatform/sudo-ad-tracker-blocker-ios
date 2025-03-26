//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Amplify
import AWSS3StoragePlugin
import Foundation

enum RulesetTransformer {

    static func transformRulesetItem(_ item: StorageListResult.Item) -> Ruleset? {
        guard
            let etag = item.eTag,
            let lastModified = item.lastModified,
            let size = item.size,
            let url = URL(string: item.key),
            url.pathComponents.count >= 2
        else {
            return nil
        }
        let name = url.deletingPathExtension().lastPathComponent
        let rawType = url.deletingLastPathComponent().lastPathComponent
        return Ruleset(
            id: item.key,
            type: RulesetType(rawValue: rawType) ?? .unknown,
            name: name,
            eTag: etag,
            lastModified: lastModified,
            size: size
        )
    }
}
