//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
@testable import SudoAdTrackerBlocker
import AWSS3

class MockS3Client: S3Client {
    var listObjectsV2InResult: Result<AWSS3ListObjectsV2Output, Error> = .success(AWSS3ListObjectsV2Output()!)
    var listObjectsV2InCalled: Bool = false
    func listObjectsV2In(bucket: String, completion: @escaping (Result<AWSS3ListObjectsV2Output, Error>) -> Void) {
        listObjectsV2InCalled = true
        completion(listObjectsV2InResult)
    }

    func listObjectsV2In(bucket: String) async throws -> AWSS3ListObjectsV2Output {
        return try await withCheckedThrowingContinuation { continuation in
            listObjectsV2In(bucket: bucket) { result in
                continuation.resume(with: result)
            }
        }
    }

    var downloadDataForCalled = false
    var downloadDataForResult: Result<Data, Error> = .success(Data())
    var downloadDataForParamRuleset: Ruleset?
    var downloadDataForParamBucket: String?
    func downloadDataFor(ruleset: Ruleset, inBucket bucket: String, completion: @escaping (Result<Data, Error>) -> Void) {
        downloadDataForCalled = true
        downloadDataForParamRuleset = ruleset
        downloadDataForParamBucket = bucket
        completion(downloadDataForResult)
    }
    
    func downloadDataFor(ruleset: Ruleset, inBucket bucket: String) async throws -> Data {
        return try await withCheckedThrowingContinuation({ continuation in
            downloadDataFor(ruleset: ruleset, inBucket: bucket) { result in
                continuation.resume(with: result)
            }
        })
    }
}
