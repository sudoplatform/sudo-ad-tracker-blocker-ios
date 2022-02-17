//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import XCTest

extension XCTest {
    // This function wraps the signature for `XCTAssertThrowsError` with `async`
    // added to the function signature and the expression closure.
    // It abstracts the pattern
    // do {
    //     _ = try await functionWeExpectToThrow
    //     XCTFail(message(), file: file, line: line)
    // } catch {
    //    // Assert error is of the correct type
    // }
    func XCTAssertThrowsAsyncError<T>(
        _ expression: @autoclosure () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line,
        _ errorHandler: (_ error: Error) -> Void = { _ in }) async {
            // This is the generic approach apple displayed when they announced
            // async await at WWDC.
            do {
                _ = try await expression()
                XCTFail(message(), file: file, line: line)
            } catch {
                errorHandler(error)
            }
        }

    // Because Apple doesn't provide an async version of XCTAssertEqual.
    // Only the first expression is async
    func XCTAssertEqualAsync<T: Sendable>(_ expression1: @autoclosure () async throws -> T,
                                          _ expression2: @autoclosure () throws -> T,
                                          _ message: @autoclosure () -> String = "",
                                          file: StaticString = #filePath,
                                          line: UInt = #line) async throws where T : Equatable {
        do {
            let e1 = try await expression1()
            XCTAssertEqual(e1, try expression2(), message(), file: file, line: line)
        } catch {
            throw error
        }
    }

    func XCTAssertTrueAsync(_ expression: @autoclosure () async throws -> Bool,
                            _ message: @autoclosure () -> String = "",
                            file: StaticString = #filePath,
                            line: UInt = #line) async {
        do {
            let value = try await expression()
            XCTAssertTrue(value)
        } catch {
            XCTFail(message())
        }
    }
}
