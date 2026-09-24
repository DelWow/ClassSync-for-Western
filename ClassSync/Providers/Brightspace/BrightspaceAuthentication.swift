import Foundation

struct BrightspaceConfiguration: Equatable, Sendable {
    static let western = BrightspaceConfiguration(
        tenantURL: URL(string: "https://westernu.brightspace.com")!,
        authorizationURL: URL(string: "https://auth.brightspace.com/oauth2/auth")!,
        tokenURL: URL(string: "https://auth.brightspace.com/core/connect/token")!,
        lpVersion: "1.49",
        leVersion: "1.82",
        scopes: [
            "enrollment:own_enrollment:read",
            "calendar:my_events:read",
            "dropbox:folders:read"
        ]
    )

    let tenantURL: URL
    let authorizationURL: URL
    let tokenURL: URL
    let lpVersion: String
    let leVersion: String
    let scopes: [String]
}

struct BrightspaceOAuthRegistration: Equatable, Sendable {
    let clientID: String
    let redirectURI: URL
}

struct BrightspaceCredential: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date

    var isExpired: Bool {
        expiresAt <= Date().addingTimeInterval(60)
    }
}

protocol BrightspaceAccessTokenProviding: Sendable {
    func accessToken() async throws -> String
}

actor BrightspaceAuthentication: BrightspaceAccessTokenProviding {
    private static let keychainAccount = "brightspace.oauth.credential"

    private let configuration: BrightspaceConfiguration
    private let keychain: KeychainService
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        configuration: BrightspaceConfiguration = .western,
        keychain: KeychainService = KeychainService()
    ) {
        self.configuration = configuration
        self.keychain = keychain
    }

    func authorizationURL(registration: BrightspaceOAuthRegistration, state: String) throws -> URL {
        guard !registration.clientID.isEmpty, !state.isEmpty else {
            throw ProviderError.invalidResponse
        }

        var components = URLComponents(url: configuration.authorizationURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: registration.clientID),
            URLQueryItem(name: "redirect_uri", value: registration.redirectURI.absoluteString),
            URLQueryItem(name: "scope", value: configuration.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state)
        ]
        guard let url = components?.url else { throw ProviderError.invalidResponse }
        return url
    }

    func store(_ credential: BrightspaceCredential) throws {
        let data = try encoder.encode(credential)
        try keychain.saveToken(data, account: Self.keychainAccount)
    }

    func accessToken() throws -> String {
        guard let data = try keychain.readToken(account: Self.keychainAccount) else {
            throw ProviderError.notAuthenticated
        }
        let credential = try decoder.decode(BrightspaceCredential.self, from: data)
        guard !credential.isExpired else { throw ProviderError.authenticationExpired }
        guard !credential.accessToken.isEmpty else { throw ProviderError.notAuthenticated }
        return credential.accessToken
    }

    func disconnect() throws {
        try keychain.deleteToken(account: Self.keychainAccount)
    }
}
