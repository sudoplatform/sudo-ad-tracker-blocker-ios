//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import SudoLogging
import AWSS3

enum S3Error: Error {

    static var missingData = "S3 list completed successfully but no data was found."

    case fatalError(description: String)
}

/// Client to interact with S3
protocol S3Client {
    /// List files in the S3 bucket
    func listObjectsV2In(bucket: String, completion: @escaping (Result<AWSS3ListObjectsV2Output, Error>) -> Void)

    /// Downloads the ruleset from the S3 bucket
    func downloadDataFor(ruleset: Ruleset, inBucket bucket: String, completion: @escaping (Result<Data, Error>) -> Void)
}

class DefaultS3Client: S3Client {

    let config: AWSServiceConfiguration

    /// Lists formatted for Apple platforms have an "apple" path in the key. The entire prefix needs to be specified to get filtering support from S3.
    var bucketPrefixFilter: String? = "/filter-lists/apple"

    init(awsServiceConfig: AWSServiceConfiguration) {
        self.config = awsServiceConfig
    }

    private var s3: AWSS3 {
        let s3Key = "com.sudoplatform.adtrackerblocker.awss3"
        
        // This function is not annotated correctly and will return nil if `register` hasn't been called.
        // we need the type annotations to force it to be optional and silence compiler warnings of the type
        // "Comparing non-optional value of type to 'nil' always returns false"
        let s3: AWSS3? = AWSS3.s3(forKey: s3Key)
        
        if let s3 = s3 {
            return s3
        } else {
            AWSS3.register(with: self.config, forKey: s3Key)
            return AWSS3.s3(forKey: s3Key)
        }
    }

    private var transferUtility: AWSS3TransferUtility {
        let transferUtilityKey = "com.sudoplatform.adtrackerblocker.awss3"
        
        if let utility = AWSS3TransferUtility.s3TransferUtility(forKey: transferUtilityKey) {
            return utility
        } else {
            AWSS3TransferUtility.register(with: config, forKey: transferUtilityKey)
            // This always succeeds unless another thread resets the aws config
            return AWSS3TransferUtility.s3TransferUtility(forKey: transferUtilityKey)!
        }
    }

    func listObjectsV2In(bucket: String, completion: @escaping (Result<AWSS3ListObjectsV2Output, Error>) -> Void) {
        guard let request = AWSS3ListObjectsV2Request() else {
            return completion(.failure(S3Error.fatalError(description: "Failed to create a request to list S3 objects.")))
        }

        request.bucket = bucket
        request.prefix = self.bucketPrefixFilter

        self.s3.listObjectsV2(request) { (output, error) in
            if let list = output {
                completion(.success(list))
            } else if let error = error {
                completion(.failure(error))
            } else {
                completion(.failure(S3Error.fatalError(description: S3Error.missingData)))
            }
        }
    }

    func downloadDataFor(ruleset: Ruleset, inBucket bucket: String, completion: @escaping (Result<Data, Error>) -> Void) {
        // Add progress updates for debugging.
        let expression = AWSS3TransferUtilityDownloadExpression()
        expression.progressBlock = { (task, progress) in
            Logger.shared.debug("Downloading Ruleset \(ruleset.name) \(Int(progress.fractionCompleted * 100))% complete.")
        }

        self.transferUtility.downloadData(fromBucket: bucket, key: ruleset.id, expression: expression) { (task, _, data, error) in
            // unused closure  params is `URL` (used if saved to an on disk url).
            
            //https://github.com/aws-amplify/aws-sdk-ios/issues/2053
            task.setCompletionHandler({ _, _, _, _ in })

            if let data = data {
                completion(.success(data))
            } else if let error = error {
                completion(.failure(error))
            } else {
                completion(.failure(S3Error.fatalError(description: S3Error.missingData)))
            }
        }
        .continueWith { (task) -> AnyObject? in
            if let error = task.error {
                completion(.failure(error))
            }

            return nil
        }
    }
}
