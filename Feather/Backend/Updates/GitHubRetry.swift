import Foundation

/// Retries GitHub requests that fail with a temporary server error or a dropped connection.
enum GitHubRetry {
    static func isTemporary(_ status: Int) -> Bool { status == 429 || (500...599).contains(status) }

    static func perform<T>(attempts: Int = 3, _ request: () async throws -> (T, URLResponse)) async throws -> (T, URLResponse) {
        var delay: UInt64 = 1_000_000_000
        var attempt = 1
        while true {
            do {
                let result = try await request()
                let status = (result.1 as? HTTPURLResponse)?.statusCode ?? 200
                guard attempt < attempts, isTemporary(status) else { return result }
            } catch let error as URLError where attempt < attempts && [.timedOut, .networkConnectionLost, .cannotConnectToHost, .dnsLookupFailed, .cannotFindHost].contains(error.code) {
                // retry below
            }
            try await Task.sleep(nanoseconds: delay)
            delay *= 2
            attempt += 1
        }
    }
}
