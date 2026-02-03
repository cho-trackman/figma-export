import Foundation
import Logging
#if os(Linux)
import FoundationNetworking
#endif

public typealias APIResult<Value> = Swift.Result<Value, Error>

public protocol Client {

    func request<T>(_ endpoint: T) throws -> T.Content where T: Endpoint

    func request<T>(
        _ endpoint: T,
        completion: @escaping (APIResult<T.Content>) -> Void ) -> URLSessionTask where T: Endpoint

    func requestWithRetry<T>(
        _ endpoint: T,
        configuration: RetryConfiguration
    ) throws -> T.Content where T: Endpoint
}

public class BaseClient: Client {

    private let baseURL: URL
    private let session: URLSession
    private let logger = Logger(label: "FigmaAPI.Client")

    public init(baseURL: URL, config: URLSessionConfiguration) {
        self.baseURL = baseURL
        session = URLSession(configuration: config, delegate: nil, delegateQueue: .main)
    }

    public func request<T>(_ endpoint: T) throws -> T.Content where T: Endpoint {
        var outResult: APIResult<T.Content>!

        let task = request(endpoint, completion: { result in
            outResult = result
        })
        task.wait()

        return try outResult.get()
    }

    public func request<T>(
        _ endpoint: T,
        completion: @escaping (APIResult<T.Content>) -> Void ) -> URLSessionTask where T: Endpoint {

        let request = endpoint.makeRequest(baseURL: baseURL)
        let task = session.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in

            // Handle network errors including timeout
            if let urlError = error as? URLError, urlError.code == .timedOut {
                completion(.failure(RateLimitError.timeout))
                return
            }

            guard let data = data, error == nil else {
                completion(.failure(error!))
                return
            }

            // Check for HTTP 429 rate limiting
            if let httpResponse = response as? HTTPURLResponse, httpResponse.isRateLimited {
                let retryAfter = httpResponse.extractRetryAfter()
                completion(.failure(RateLimitError.rateLimited(retryAfter: retryAfter)))
                return
            }

            let content = APIResult<T.Content>(catching: { () -> T.Content in
                return try endpoint.content(from: response, with: data)
            })

            completion(content)
        }
        task.resume()
        return task
    }

    public func requestWithRetry<T>(
        _ endpoint: T,
        configuration: RetryConfiguration = .default
    ) throws -> T.Content where T: Endpoint {

        var lastError: Error?
        var currentBackoff = configuration.initialBackoffSeconds

        for attempt in 0..<configuration.maxRetries {
            do {
                let result = try request(endpoint)
                // Delay after successful request to prevent hitting rate limits on subsequent calls
                if configuration.requestDelaySeconds > 0 {
                    logger.info("Throttling: waiting \(String(format: "%.1f", configuration.requestDelaySeconds))s before next request")
                    sleep(forTimeInterval: configuration.requestDelaySeconds)
                }
                return result
            } catch let error as RateLimitError {
                switch error {
                case .rateLimited(let retryAfter):
                    // Exit immediately if retry-after exceeds max allowed wait time
                    if retryAfter > configuration.maxRetryAfterSeconds {
                        throw RateLimitError.rateLimitExceeded(retryAfter: retryAfter)
                    }

                    logger.warning("Rate limited by Figma API. Waiting \(Int(retryAfter))s before retry \(attempt + 1)/\(configuration.maxRetries)")
                    sleep(forTimeInterval: retryAfter)
                    lastError = error

                case .timeout:
                    // Exponential backoff for timeout
                    logger.warning("Request timed out. Waiting \(Int(currentBackoff))s before retry \(attempt + 1)/\(configuration.maxRetries)")
                    sleep(forTimeInterval: currentBackoff)
                    currentBackoff *= configuration.backoffMultiplier
                    lastError = error

                case .rateLimitExceeded:
                    // Do not retry, exit immediately
                    throw error
                }
            } catch {
                // Other errors: do not retry
                throw error
            }
        }

        // All retries exhausted
        if let lastError = lastError {
            throw lastError
        }
        throw RateLimitError.timeout
    }

}

private extension URLSessionTask {

    /// Wait until task completed.
    func wait() {
        guard let timeout = currentRequest?.timeoutInterval else { return }
        let limitDate = Date(timeInterval: timeout, since: Date())
        while state == .running && RunLoop.current.run(mode: .default, before: limitDate) {
            // wait
        }
    }

}

/// Sleeps for the specified interval while keeping the RunLoop responsive.
/// Uses RunLoop when possible to process pending callbacks, with Thread.sleep
/// fallback when RunLoop has no active sources (prevents immediate return).
/// On Linux, uses Thread.sleep directly as RunLoop behavior differs.
private func sleep(forTimeInterval interval: TimeInterval) {
    #if os(Linux)
    Thread.sleep(forTimeInterval: interval)
    #else
    let limitDate = Date(timeIntervalSinceNow: interval)
    while Date() < limitDate {
        if !RunLoop.current.run(mode: .default, before: limitDate) {
            Thread.sleep(forTimeInterval: 0.1)
        }
    }
    #endif
}
