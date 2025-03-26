//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

extension FileManager {
    static var cachesDirectory: URL {
        return `default`.cachesDirectory
    }

    var cachesDirectory: URL {
        return urls(for: .cachesDirectory, in: .userDomainMask).last!
    }

    static var documentDirectory: URL {
        return `default`.documentDirectory
    }

    var documentDirectory: URL {
        return urls(for: .documentDirectory, in: .userDomainMask).last!
    }
}
