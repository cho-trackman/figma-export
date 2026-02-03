// ABOUTME: Configuration for retry behavior on API failures
// ABOUTME: Defines max retries, backoff strategy, and timeout thresholds

import Foundation

public struct RetryConfiguration {
    public let maxRetries: Int
    public let maxRetryAfterSeconds: TimeInterval  // Exit if Retry-After exceeds this
    public let initialBackoffSeconds: TimeInterval
    public let backoffMultiplier: Double
    public let requestDelaySeconds: TimeInterval  // Delay after each successful request to prevent rate limiting

    public init(
        maxRetries: Int = 3,
        maxRetryAfterSeconds: TimeInterval = 300,  // 5 minutes
        initialBackoffSeconds: TimeInterval = 1.0,
        backoffMultiplier: Double = 2.0,
        requestDelaySeconds: TimeInterval = 0
    ) {
        self.maxRetries = maxRetries
        self.maxRetryAfterSeconds = maxRetryAfterSeconds
        self.initialBackoffSeconds = initialBackoffSeconds
        self.backoffMultiplier = backoffMultiplier
        self.requestDelaySeconds = requestDelaySeconds
    }

    public static let `default` = RetryConfiguration()
}
