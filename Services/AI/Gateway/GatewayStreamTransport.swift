import Foundation
import Core

// MARK: - Stream transport

/// One opened gateway response. Lines are already split; the SSE blank line is an empty string.
public struct GatewayOpenedStream: Sendable {
    public var statusCode: Int
    /// Parsed from the `Retry-After` response header when present (seconds).
    public var retryAfter: TimeInterval?
    public var lines: AsyncThrowingStream<String, Error>
    /// Parsed from the `x-mercury-budget-*` headers when the gateway sends them.
    public var budget: CloudBudget?

    public init(
        statusCode: Int,
        lines: AsyncThrowingStream<String, Error>,
        retryAfter: TimeInterval? = nil,
        budget: CloudBudget? = nil
    ) {
        self.statusCode = statusCode
        self.retryAfter = retryAfter
        self.lines = lines
        self.budget = budget
    }
}

/// Production uses URLSession. Tests inject lines so CI does not depend on URLProtocol byte delivery.
public struct GatewayStreamTransport: Sendable {
    public var open: @Sendable (URLRequest) async throws -> GatewayOpenedStream

    public init(open: @escaping @Sendable (URLRequest) async throws -> GatewayOpenedStream) {
        self.open = open
    }

    /// Ephemeral session that refuses HTTP redirects (keeps prompt body on the validated endpoint).
    public static func makeSecureSession(configuration: URLSessionConfiguration = .ephemeral) -> URLSession {
        URLSession(
            configuration: configuration,
            delegate: GatewayRedirectRejector.shared,
            delegateQueue: nil
        )
    }

    /// Shared ephemeral, redirect-refusing session for every other gateway call (`/v1/config`
    /// carries the device token; `/v1/health` must not follow redirects either). `URLSession.shared`
    /// follows redirects and writes responses to the shared disk cache.
    public static let secureSession = makeSecureSession()

    public static func urlSession(_ session: URLSession) -> GatewayStreamTransport {
        GatewayStreamTransport { request in
            let (bytes, response) = try await session.bytes(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw AppError.networkUnavailable
            }
            let lines = AsyncThrowingStream<String, Error> { continuation in
                let task = Task {
                    do {
                        for try await line in bytes.lines {
                            continuation.yield(line)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { @Sendable _ in task.cancel() }
            }
            return GatewayOpenedStream(
                statusCode: http.statusCode,
                lines: lines,
                retryAfter: Self.parseRetryAfter(http),
                budget: CloudBudget.parse(http.allHeaderFields)
            )
        }
    }

    /// Integer-second `Retry-After` only (gateway contract). HTTP-date forms are ignored.
    public static func parseRetryAfter(_ response: HTTPURLResponse) -> TimeInterval? {
        guard let raw = response.value(forHTTPHeaderField: "Retry-After")?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty,
              let seconds = TimeInterval(raw),
              seconds >= 0 else {
            return nil
        }
        return seconds
    }
}

/// Rejects every HTTP redirect so POSTed prompts never leave the validated gateway URL.
/// Stateless `final` NSObject subclass, so it is checked `Sendable` (issue #252).
final class GatewayRedirectRejector: NSObject, URLSessionTaskDelegate, Sendable {
    static let shared = GatewayRedirectRejector()

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
