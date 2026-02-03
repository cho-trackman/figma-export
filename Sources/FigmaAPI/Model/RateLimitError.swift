// ABOUTME: Errors related to Figma API rate limiting
// ABOUTME: Handles HTTP 429, timeouts, and retry-after exceeded scenarios

import Foundation

public enum RateLimitError: LocalizedError, Equatable {
    case rateLimited(retryAfter: TimeInterval)
    case rateLimitExceeded(retryAfter: TimeInterval)  // > max allowed wait time
    case timeout

    public var errorDescription: String? {
        switch self {
        case .rateLimited(let retryAfter):
            return "Rate limited by Figma API. Retrying in \(Int(retryAfter)) seconds..."
        case .rateLimitExceeded(let retryAfter):
            let minutes = Int(retryAfter / 60)
            return "Figma API rate limit exceeded. Retry-After: \(minutes) minutes. " +
                   "Please wait and try again later, or check your API usage."
        case .timeout:
            return "Request to Figma API timed out. Retrying..."
        }
    }
}
