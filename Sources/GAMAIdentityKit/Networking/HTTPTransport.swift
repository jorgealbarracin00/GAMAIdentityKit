import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct HTTPRequest: Sendable {
    let method: String
    let path: String
    var body: Data?
    var bearerToken: String?
}

struct HTTPResponse: Sendable {
    let data: Data
    let statusCode: Int
}

protocol HTTPTransport: Sendable {
    func execute(_ request: HTTPRequest) async throws -> HTTPResponse
}

final class URLSessionTransport: HTTPTransport, @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let logger: DebugLogger

    init(baseURL: URL, session: URLSession = .shared, logger: DebugLogger) {
        self.baseURL = baseURL
        self.session = session
        self.logger = logger
    }

    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        let endpoint = baseURL.appending(path: request.path)
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        if request.body != nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let token = request.bearerToken {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        logger.log("\(request.method) /\(request.path)")
        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GAMAIdentityError.invalidResponse
            }
            logger.log("Response \(httpResponse.statusCode) for /\(request.path)")
            return HTTPResponse(data: data, statusCode: httpResponse.statusCode)
        } catch let error as GAMAIdentityError {
            throw error
        } catch {
            throw GAMAIdentityError.network
        }
    }
}
