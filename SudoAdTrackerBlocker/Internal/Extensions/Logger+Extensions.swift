//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import SudoLogging

/// Global log level, so we can change it when it's too chatty.
var globalLogDriver: SudoLogging.LogDriverProtocol = {
    #if DEBUG
    return NSLogDriver(level: .debug)
    #else
    return NSLogDriver(level: .info)
    #endif
}()

/// Global shared logger so we don't have to pass references everywhere we want logging capabilities.
extension Logger {
    static var shared: Logger = {
        return Logger(identifier: "com.anonyome.sudoplatform.adtrackerblocker", driver: globalLogDriver)
    }()
}

extension DefaultSudoAdTrackerBlockerClient {

    /// The global log level used by the ad tracker blocker client
    static var logLevel: SudoLogging.LogLevel {
        get {
            return globalLogDriver.logLevel
        }
        set {
            globalLogDriver.logLevel = newValue
        }
    }
}
