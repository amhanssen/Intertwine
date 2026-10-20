import Foundation
import Security

/// The shared online database (Supabase) that the couple app and the guest website both use.
/// Talks to Supabase's web API directly, so the project needs no extra packages.
/// The tables and their access rules are in supabase/schema.sql.
enum Supabase {
    static let url = URL(string: "https://nhdfuarjvwoeghgyxtvw.supabase.co")!
    /// Meant to be public. On its own it can only call the guest functions; a couple's
    /// sign-in is what lets the app reach their wedding.
    static let publishableKey = "sb_publishable_yDztgS26co172rYYSgZ8-w_KLVdKchJ"

    /// The guest website. A guest's personal link adds `?invite=` and their code.
    static let guestSite = URL(string: "https://amhanssen.github.io/Intertwine/")!

    static func inviteLink(for code: String) -> URL {
        var parts = URLComponents(url: guestSite, resolvingAgainstBaseURL: false)!
        parts.queryItems = [URLQueryItem(name: "invite", value: code)]
        return parts.url!
    }

    /// A new guest's invite code: 16 random letters and digits, like the database makes.
    static func makeInviteCode() -> String {
        String(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(16))
    }
}

// MARK: - Errors

enum SupabaseError: LocalizedError {
    case notSignedIn
    case needsEmailConfirmation
    case server(String)
    case offline

    var errorDescription: String? {
        switch self {
        case .notSignedIn: "You’re signed out. Sign in again to keep your wedding in sync."
        case .needsEmailConfirmation: "Check your email and tap the link to confirm your account, then sign in."
        case .server(let message): message
        case .offline: "You’re offline. Your changes are saved on this phone and will sync when you’re back online."
        }
    }
}

// MARK: - Sign-in

/// A signed-in couple. Kept in the Keychain, so it survives the app closing.
struct Session: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var userID: UUID
    var email: String
}

enum Auth {
    private struct TokenResponse: Decodable {
        let access_token: String?
        let refresh_token: String?
        let expires_in: Double?
        let user: User?
        // Sign-up without a session (email confirmation on) returns the user at the top level.
        let id: UUID?
        let email: String?

        struct User: Decodable {
            let id: UUID
            let email: String?
        }
    }

    private struct ErrorResponse: Decodable {
        let msg: String?
        let message: String?
        let error_description: String?
        let error_code: String?
    }

    /// Creates the couple's account. Throws `needsEmailConfirmation` when Supabase wants the
    /// email confirmed first.
    static func signUp(email: String, password: String) async throws -> Session {
        let response = try await post("signup", ["email": email, "password": password])
        guard let session = session(from: response, email: email) else { throw SupabaseError.needsEmailConfirmation }
        return session
    }

    static func signIn(email: String, password: String) async throws -> Session {
        let response = try await post("token?grant_type=password", ["email": email, "password": password])
        guard let session = session(from: response, email: email) else { throw SupabaseError.server("Couldn’t sign in.") }
        return session
    }

    static func refresh(_ old: Session) async throws -> Session {
        let response = try await post("token?grant_type=refresh_token", ["refresh_token": old.refreshToken])
        guard let session = session(from: response, email: old.email) else { throw SupabaseError.notSignedIn }
        return session
    }

    private static func session(from r: TokenResponse, email: String) -> Session? {
        guard let access = r.access_token, let refresh = r.refresh_token, let user = r.user else { return nil }
        return Session(accessToken: access, refreshToken: refresh,
                       expiresAt: Date().addingTimeInterval(r.expires_in ?? 3600),
                       userID: user.id, email: user.email ?? email)
    }

    private static func post(_ path: String, _ body: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: "auth/v1/\(path)", relativeTo: Supabase.url)!)
        request.httpMethod = "POST"
        request.setValue(Supabase.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await REST.send(request)
        guard (200..<300).contains(response.statusCode) else {
            let error = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw SupabaseError.server(friendly(error?.error_code, error?.msg ?? error?.message ?? error?.error_description))
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    /// Supabase's messages are written for developers; these are for couples.
    private static func friendly(_ code: String?, _ message: String?) -> String {
        switch code {
        case "invalid_credentials": "That email and password don’t match. Check them and try again."
        case "user_already_exists", "email_exists": "There’s already an account with that email. Sign in instead."
        case "weak_password": "Choose a longer password: at least 8 characters."
        case "email_not_confirmed": SupabaseError.needsEmailConfirmation.errorDescription!
        case "over_email_send_rate_limit", "over_request_rate_limit": "Too many tries. Wait a minute and try again."
        case "validation_failed": "Check that the email address is complete."
        default: message ?? "Something went wrong. Try again."
        }
    }
}

/// Keeps the session in the Keychain rather than in a plain file.
enum SessionStore {
    private static let account = "supabase.session"

    static func load() -> Session? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: account,
                                    kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(Session.self, from: data)
    }

    static func save(_ session: Session?) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
        guard let session, let data = try? JSONEncoder().encode(session) else { return }
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }
}

// MARK: - Database

/// Reads and writes tables as the signed-in couple. Supabase's access rules make sure a couple
/// only ever reaches their own wedding.
struct REST {
    let session: Session

    func select<T: Decodable>(_ table: String, _ query: String) async throws -> [T] {
        let (data, _) = try await request("GET", "\(table)?\(query)")
        return try REST.decoder.decode([T].self, from: data)
    }

    /// Adds rows, or replaces rows with the same id.
    func upsert<T: Encodable>(_ table: String, _ rows: [T], onConflict: String = "id") async throws {
        guard !rows.isEmpty else { return }
        _ = try await request("POST", "\(table)?on_conflict=\(onConflict)", body: try REST.encoder.encode(rows),
                              prefer: "resolution=merge-duplicates,return=minimal")
    }

    func delete(_ table: String, _ query: String) async throws {
        _ = try await request("DELETE", "\(table)?\(query)", prefer: "return=minimal")
    }

    private func request(_ method: String, _ path: String, body: Data? = nil, prefer: String? = nil) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: URL(string: "rest/v1/\(path)", relativeTo: Supabase.url)!)
        request.httpMethod = method
        request.httpBody = body
        request.setValue(Supabase.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let prefer { request.setValue(prefer, forHTTPHeaderField: "Prefer") }
        let (data, response) = try await REST.send(request)
        if response.statusCode == 401 { throw SupabaseError.notSignedIn }
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(String(data: data, encoding: .utf8) ?? "Request failed (\(response.statusCode))")
        }
        return (data, response)
    }

    static func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            return (data, response as! HTTPURLResponse)
        } catch let error as URLError where [.notConnectedToInternet, .networkConnectionLost, .timedOut,
                                             .cannotConnectToHost, .cannotFindHost].contains(error.code) {
            throw SupabaseError.offline
        }
    }

    static let encoder = JSONEncoder()
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = timestamp.date(from: text) ?? timestampNoFraction.date(from: text) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date \(text)"))
        }
        return decoder
    }()

    private static let timestamp: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let timestampNoFraction = ISO8601DateFormatter()
}
