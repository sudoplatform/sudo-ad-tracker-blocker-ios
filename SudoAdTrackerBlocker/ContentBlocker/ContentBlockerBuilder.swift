//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

class ContentBlockerBuilder {

    let rulesetData: RulesetData

    /// Creates a builder with a base ruleset.  These are provided by the service (e.g. S3).
    /// - Parameter rulesetData: The base ruleset to use
    init(rulesetData: RulesetData) {
        self.rulesetData = rulesetData
    }

    /// Combines the base ruleset with the provided exception list.
    /// - Parameter exceptions: The exceptions to be applied to the base list
    /// - Returns: A content blocker containing the list plus exceptions.
    func buildWithExceptions(exceptions: [BlockingException]) -> ContentBlocker? {

        // read ruleset data
        guard var rulesetData =  String(data: self.rulesetData.data, encoding: .utf8) else {
            return nil
        }

        if exceptions.isEmpty == false {
            // Create a string list of exceptions.  This will be injected into the ruleset data
            let encodedExceptionList = self.encode(exceptions: exceptions).joined(separator: ",")

            // Inject the exceptions by crafting a small chunk of json in apples rule list format with the exceptions included.
            let exceptionString = """
                                    ,{
                                        "action": {
                                            "type": "ignore-previous-rules"
                                        },
                                        "trigger": {
                                            "url-filter": ".*",
                                            "if-domain":[\(encodedExceptionList)],
                                            "load-type": ["third-party"]
                                        }
                                    }]
                                    """
            // The ruleset data is a json array.  Remove any whitespace/newlines and the "]" character at the end to open the array back up and add the exception json. The comma and closing ] are included in the crafted exception json.
            rulesetData = rulesetData.trimmingCharacters(in: .whitespacesAndNewlines).dropLast() + exceptionString
        }

        // Generate an id for the exceptions.
        let id = generateIdentifierFor(ruleset: self.rulesetData.meta, with: exceptions)

        return ContentBlocker.init(id: id, baseRuleset: self.rulesetData.meta, rulesetData: rulesetData, exceptions: exceptions)
    }

    /// Returns an identifier for a base ruleset and list of `BlockException`.
    /// This id uniquely identifies this combination and can be used with WKContentRuleListStore
    ///
    /// - Parameters:
    ///   - whitelist: The whitelist we are using (empty implies base/default ruleset)
    ///   - sudoId: Should not be empty if whitelist is not empty
    ///
    /// - Returns: The current ruleset including any whitelisted domains
    func generateIdentifierFor(ruleset: Ruleset, with exceptions: [BlockingException]) -> String {
        // the approach here is to create a unique string using a combo of ruleset id + exceptions.
        // The list should be sorted to maintain the unique name.  The resulting string is hashed
        // to create the id.
        let exceptionString = exceptions.map({$0}).sorted().joined(separator: ",")
        return "\(ruleset.id)-\(exceptionString)".md5sum
    }

    /// Encode the blocking exceptions
    func encode(exceptions: [BlockingException]) -> [String] {
        // Map raw value of the exceptions and encode.  The strings must be lower case or they won't compile.
        return exceptions.compactMap {
            // Make sure exceptions in the form of "*google.com" don't have an extra * added.
            if $0.first == "*" {
                return "\"\($0.lowercased())\""
            }
            else {
                return "\"*\($0.lowercased())\""
            }
        }
    }
}

import CommonCrypto
extension String {
    /// Returns the md5sum for a string to provide a simple unique representation of the string.
    /// **NOTE** Not fit for purpose of password hashing. Should be solely used to derive a unique
    /// hex sequence from self
    public var md5sum: String {
        let data = Data(utf8)
        let hashLength = Int(CC_MD5_DIGEST_LENGTH)
        var hash = [UInt8](repeating: 0, count: hashLength)

        data.withUnsafeBytes { bytes in
            _ = CC_MD5(bytes.baseAddress, CC_LONG(bytes.count), &hash)
        }
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }
}
