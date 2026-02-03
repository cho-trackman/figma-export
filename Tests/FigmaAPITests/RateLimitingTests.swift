// ABOUTME: Tests for rate limiting error types and retry configuration
// ABOUTME: Validates error messages, retry-after parsing, and configuration defaults

import XCTest
import Foundation
#if os(Linux)
import FoundationNetworking
#endif
@testable import FigmaAPI

final class RateLimitingTests: XCTestCase {

    // MARK: - RateLimitError Tests

    func testRateLimitedErrorDescription() {
        let error = RateLimitError.rateLimited(retryAfter: 60)
        XCTAssertEqual(
            error.errorDescription,
            "Rate limited by Figma API. Retrying in 60 seconds..."
        )
    }

    func testRateLimitExceededErrorDescription() {
        let error = RateLimitError.rateLimitExceeded(retryAfter: 600)
        XCTAssertEqual(
            error.errorDescription,
            "Figma API rate limit exceeded. Retry-After: 10 minutes. " +
            "Please wait and try again later, or check your API usage."
        )
    }

    func testTimeoutErrorDescription() {
        let error = RateLimitError.timeout
        XCTAssertEqual(
            error.errorDescription,
            "Request to Figma API timed out. Retrying..."
        )
    }

    func testRateLimitErrorEquality() {
        XCTAssertEqual(
            RateLimitError.rateLimited(retryAfter: 60),
            RateLimitError.rateLimited(retryAfter: 60)
        )
        XCTAssertNotEqual(
            RateLimitError.rateLimited(retryAfter: 60),
            RateLimitError.rateLimited(retryAfter: 120)
        )
        XCTAssertEqual(RateLimitError.timeout, RateLimitError.timeout)
    }

    // MARK: - RetryConfiguration Tests

    func testDefaultConfiguration() {
        let config = RetryConfiguration.default

        XCTAssertEqual(config.maxRetries, 3)
        XCTAssertEqual(config.maxRetryAfterSeconds, 300)  // 5 minutes
        XCTAssertEqual(config.initialBackoffSeconds, 1.0)
        XCTAssertEqual(config.backoffMultiplier, 2.0)
    }

    func testCustomConfiguration() {
        let config = RetryConfiguration(
            maxRetries: 5,
            maxRetryAfterSeconds: 600,
            initialBackoffSeconds: 2.0,
            backoffMultiplier: 3.0,
            requestDelaySeconds: 0.5
        )

        XCTAssertEqual(config.maxRetries, 5)
        XCTAssertEqual(config.maxRetryAfterSeconds, 600)
        XCTAssertEqual(config.initialBackoffSeconds, 2.0)
        XCTAssertEqual(config.backoffMultiplier, 3.0)
        XCTAssertEqual(config.requestDelaySeconds, 0.5)
    }

    func testDefaultConfigurationHasZeroRequestDelay() {
        let config = RetryConfiguration.default
        XCTAssertEqual(config.requestDelaySeconds, 0)
    }

    // MARK: - Retry-After Header Parsing Tests

    func testExtractRetryAfterFromNumericHeader() {
        let headerFields = ["Retry-After": "120"]
        let response = HTTPURLResponse(
            url: URL(string: "https://api.figma.com")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: headerFields
        )!

        let retryAfter = response.extractRetryAfter()
        XCTAssertEqual(retryAfter, 120)
    }

    func testExtractRetryAfterDefaultsTo60WhenMissing() {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.figma.com")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: [:]
        )!

        let retryAfter = response.extractRetryAfter()
        XCTAssertEqual(retryAfter, 60)  // Default fallback
    }

    func testExtractRetryAfterDefaultsTo60WhenInvalid() {
        let headerFields = ["Retry-After": "not-a-number"]
        let response = HTTPURLResponse(
            url: URL(string: "https://api.figma.com")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: headerFields
        )!

        let retryAfter = response.extractRetryAfter()
        XCTAssertEqual(retryAfter, 60)  // Default fallback
    }

    // MARK: - Rate Limit Detection Tests

    func testIsRateLimitedForStatus429() {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.figma.com")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: [:]
        )!

        XCTAssertTrue(response.isRateLimited)
    }

    func testIsNotRateLimitedForStatus200() {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.figma.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: [:]
        )!

        XCTAssertFalse(response.isRateLimited)
    }

    func testIsNotRateLimitedForStatus500() {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.figma.com")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: [:]
        )!

        XCTAssertFalse(response.isRateLimited)
    }
}
