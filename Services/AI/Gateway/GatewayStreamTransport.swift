import Foundation
import Core

// MARK: - Stream transport

/// One opened gateway response. Lines are already split; the SSE blank line is an empty string.
public struct GatewayOpenedStream: Sendable {
    public var statusCode: Int
    public var lines: AsyncThrowingStream<String, Error>

    public init(statusCode: Int, lines: AsyncThrowingStream<String, Error>) {
        self.statusCode = statusCode
        self.lines = lines
    }
}

/// Production uses URLSession. Tests inject lines so CI does not depend on URLProtocol byte delivery.
public struct GatewayStreamTransport: Sendable {
    public var open: @Sendable (URLRequest) async throws -> GatewayOpenedStream

    public init(open: @escaping @Sendable (URLRequest) async throws -> GatewayOpenedStream) {
        self.open = open
    }

    /// Ephemeral session that refuses HTTP redirects (keeps prompt body on the validated endpoint).
    public static func makeSecureSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        return URLSession(
            configuration: config,
            delegate: GatewayRedirectRejector.shared,
            delegateQueue: nil
        )
    }

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
            return GatewayOpenedStream(statusCode: http.statusCode, lines: lines)
        }
    }
}

/// Rejects every HTTP redirect so POSTed prompts never leave the validated gateway URL.
private final class GatewayRedirectRejector: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
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
