// ABOUTME: Extension to HTTPURLResponse for rate limit detection
// ABOUTME: Extracts Retry-After header and checks for HTTP 429 status

import Foundation
#if os(Linux)
import FoundationNetworking
#endif

public extension HTTPURLResponse {

    /// Returns true if the response indicates rate limiting (HTTP 429)
    var isRateLimited: Bool {
        statusCode == 429
    }

    /// Extracts the Retry-After value from response headers
    /// - Returns: The number of seconds to wait before retrying, defaults to 60 if not present or invalid
    func extractRetryAfter() -> TimeInterval {
        // Retry-After can be in seconds (e.g., "120") or HTTP date format
        // We only support the seconds format for simplicity
        // Use allHeaderFields for compatibility with macOS 10.13+
        let headers = allHeaderFields
        if let retryAfterString = headers["Retry-After"] as? String,
           let seconds = TimeInterval(retryAfterString) {
            return seconds
        }
        // Also check lowercase variant (HTTP headers are case-insensitive)
        if let retryAfterString = headers["retry-after"] as? String,
           let seconds = TimeInterval(retryAfterString) {
            return seconds
        }
        return 60  // Default fallback
    }
}
