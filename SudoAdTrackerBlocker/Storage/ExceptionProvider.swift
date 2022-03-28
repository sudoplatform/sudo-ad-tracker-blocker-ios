//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

protocol ExceptionProvider {
    ///
    /// Retrieves all the stored Blocking Exceptions.
    func get() -> [BlockingException]

    /// Adds an array of Blocking Exceptions to be persisted.
    /// - Parameters:
    ///   - exceptions: The Blocking Exceptions to be added to storage.
    func add(_ exceptions: [BlockingException])

    /// Removes an array of Blocking Exceptions that have been persisted.
    /// - Parameters:
    ///   - exceptions: The Blocking Exceptions to be removed from storage.
    func remove(_ exceptions: [BlockingException])

    /// Removes all stored Blocking Exceptions.
    func removeAll()
}

/// Encapsulates the use of the property wrapper to handle the interactions with Blocking Exceptions
class DefaultExceptionProvider: ExceptionProvider {

    @FileBacked(name: "RulesetExceptions", storage: FileManager.documentDirectory, defaultValue: [])
    private var _exceptions: [BlockingException]

    func get() -> [BlockingException] {
        return _exceptions
    }

    func add(_ exceptions: [BlockingException]) {
        if exceptions.isEmpty { return }
        _exceptions.append(contentsOf: exceptions)
    }

    func remove(_ exceptions: [BlockingException]) {
        if _exceptions.isEmpty { return }
        
        for toRemove in exceptions {
            _exceptions.removeAll {
                $0 == toRemove
            }
        }
    }

    func removeAll() {
        _exceptions.removeAll()
    }
}

/// @propertyWrapper around FileManager
@propertyWrapper struct FileBacked<Value: Codable> {
    let name: String
    let storage: URL
    let defaultValue: Value
    var fileName: URL {
        storage.appendingPathComponent("\(name).json")
    }
    var wrappedValue: Value {
        get {
            do {
                guard FileManager.default.fileExists(atPath: fileName.path) else {
                    return defaultValue
                }
                let jsonString = try String(contentsOf: fileName, encoding: .utf8)
                guard let data = jsonString.data(using: .utf8) else {
                    return defaultValue
                }
                let value = try JSONDecoder().decode(Value.self, from: data)
                return value
            } catch {
                NSLog("Failed to read: \(fileName), error: \(error)")
                return defaultValue
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                guard let jsonString = String(data: data, encoding: .utf8) else {
                    return
                }
                try jsonString.write(to: fileName, atomically: true, encoding: .utf8)
            } catch {
                NSLog("Failed to write: \(fileName), error: \(error)")
            }
        }
    }
}
