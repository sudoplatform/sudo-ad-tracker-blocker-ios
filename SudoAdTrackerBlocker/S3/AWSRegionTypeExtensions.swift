//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import AWSS3

/// Used to convert a region string from our config file to a `AWSRegionType`.
extension AWSRegionType {
    static func regionTypeForString(regionString: String) -> AWSRegionType {
        switch regionString {
        case "us-east-1": return .USEast1
        case "us-east-2": return .USEast2
        case "us-west-1": return .USWest1
        case "us-west-2": return .USWest2
        case "eu-west-1": return .EUWest1
        case "eu-west-2": return .EUWest2
        case "eu-west-3": return .EUWest3
        case "eu-north-1": return .EUNorth1
        case "eu-central-1": return .EUCentral1
        case "ap-northeast-1": return .APNortheast1
        case "ap-northeast-2": return .APNortheast2
        case "ap-southeast-1": return .APSoutheast1
        case "ap-southeast-2": return .APSoutheast2
        case "ap-south-1": return .APSouth1
        case "ap-east-1": return .APEast1
        case "sa-east-1": return .SAEast1
        case "cn-north-1": return .CNNorth1
        case "cn-northwest-1": return .CNNorthWest1
        case "ca-central-1": return .CACentral1
        case "me-south-1": return .MESouth1
        case "us-gov-east-1": return .USGovEast1
        case "us-gov-west-1": return .USGovWest1
        default: return .Unknown
        }
    }
}
