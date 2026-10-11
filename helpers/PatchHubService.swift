import CryptoKit
import Foundation

struct RemotePackage: Decodable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let color1: String
    let color2: String
    let tools: [RemoteTool]
}

struct RemoteTool: Decodable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let color1: String
    let color2: String
    let apiUrl: String?          // nil when server hides it (proxy mode)
    let inputType: String       // "single" | "dual"
    let input1Label: String
    let input1Placeholder: String
    let input2Label: String?
    let input2Placeholder: String?
    let runLabel: String
    let isLive: Bool
    let order: Int

    func buildURL(input1: String, input2: String = "") -> URL? {
        guard var s = apiUrl else { return nil }
        if inputType == "dual" {
            s = s.replacingOccurrences(of: "{tc}", with: input1)
            s = s.replacingOccurrences(of: "{uid}", with: input2)
        } else {
            s = s.replacingOccurrences(of: "{uid}", with: input1)
        }
        return URL(string: s)
    }
}

struct RemotePatchSummary: Decodable, Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let version: String
    let fileName: String
    let sizeBytes: Int64
    let sha256: String
    let createdAt: String
    let gameId: String?
    let containerId: String?
    let password: String?
}

/// A tab within a game's patch screen (e.g. Proxy / Định Vị / Mod NV), so a game's patches can
/// be grouped instead of always showing as one flat list.
struct RemoteContainerSummary: Decodable, Identifiable, Equatable {
    let id: String
    let gameId: String
    let name: String
    let icon: String
    let order: Int
    let videoUrl: String?
}

struct GameNotice: Decodable, Identifiable {
    let gameId: String
    let title: String
    let message: String
    let linkLabel: String
    let linkURL: String
    var id: String { gameId }
}

struct RemoteGameSummary: Decodable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let bundleID: String
    let bannerColor: String
    let iconPath: String?
    let createdAt: String
    let type: String?

    var iconURL: URL? {
        guard let iconPath else { return nil }
        return PatchHubService.baseURL.appendingPathComponent(String(iconPath.dropFirst()))
    }
}

enum PatchHubError: Error {
    case invalidResponse
    case checksumMismatch
}

enum PatchHubService {
    // XOR key = 0x4B — no plaintext strings in the compiled binary
    // Base URL: https://patches.cheatiosvip.net
    private static let _bu: [UInt8] = [
        0x23, 0x3F, 0x3F, 0x3B, 0x38, 0x71, 0x64, 0x64, 0x3B, 0x2A, 0x3F, 0x28, 0x23, 0x2E,
        0x38, 0x65, 0x28, 0x23, 0x2E, 0x2A, 0x3F, 0x22, 0x24, 0x38, 0x3D, 0x22, 0x3B, 0x65,
        0x25, 0x2E, 0x3F
    ]
    // CLIENT_TOKEN: aa15c20b95c22b8d4a924fb6e8cf88d711111122
    private static let _t: [UInt8] = [
        0x2A, 0x2A, 0x7A, 0x7E, 0x28, 0x79, 0x7B, 0x29, 0x72, 0x7E, 0x28, 0x79, 0x79, 0x29,
        0x73, 0x2F, 0x7F, 0x2A, 0x72, 0x79, 0x7F, 0x2D, 0x29, 0x7D, 0x2E, 0x73, 0x28, 0x2D,
        0x73, 0x73, 0x2F, 0x7C, 0x7A, 0x7A, 0x7A, 0x7A, 0x7A, 0x7A, 0x79, 0x79
    ]
    // API paths (obfuscated)
    private static let _g:  [UInt8] = [0x3D, 0x7F, 0x33, 0x64, 0x38, 0x2C]                                                                             // v4x/sg
    private static let _p:  [UInt8] = [0x3D, 0x7F, 0x33, 0x64, 0x38, 0x3B]                                                                             // v4x/sp
    private static let _c:  [UInt8] = [0x3D, 0x7F, 0x33, 0x64, 0x38, 0x28]                                                                             // v4x/sc
    private static let _n:  [UInt8] = [0x3D, 0x7F, 0x33, 0x64, 0x38, 0x25]                                                                             // v4x/sn
    private static let _a:  [UInt8] = [0x3D, 0x7F, 0x33, 0x64, 0x38, 0x2A]                                                                             // v4x/sa
    private static let _dv: [UInt8] = [0x3D, 0x7F, 0x33, 0x64, 0x2F, 0x3D]                                                                             // v4x/dv
    private static let _cl: [UInt8] = [0x3D, 0x7F, 0x33, 0x64, 0x28, 0x27]                                                                             // v4x/cl
    private static let _px: [UInt8] = [0x3D, 0x7F, 0x33, 0x64, 0x3B, 0x33]                                                                             // v4x/px
    private static let _bl: [UInt8] = [0x3D, 0x7F, 0x33, 0x64, 0x29, 0x27]                                                                             // v4x/bl
    private static let _bls: [UInt8] = [0x3D, 0x7F, 0x33, 0x64, 0x29, 0x27, 0x38]                                                                      // v4x/bls
    private static let _vt:  [UInt8] = [0x3D, 0x7F, 0x33, 0x64, 0x38, 0x3F]                                                                            // v4x/st
    private static let _dns: [UInt8] = [0x3D, 0x7F, 0x33, 0x64, 0x38, 0x2F, 0x25, 0x38]                                                               // v4x/sdns
    private static let _sec: [UInt8] = [0x3D, 0x7F, 0x33, 0x64, 0x38, 0x2E, 0x28]                                                                    // v4x/sec
    private static let _gn: [UInt8] = [0x64, 0x2A, 0x3B, 0x22, 0x64, 0x2C, 0x2A, 0x26, 0x2E, 0x66, 0x25, 0x24, 0x3F, 0x22, 0x28, 0x2E, 0x38]       // api/game-notices
    private static let _r:  [UInt8] = [0x2A, 0x3B, 0x22, 0x64, 0x3D, 0x79, 0x64, 0x20, 0x2E, 0x32, 0x38, 0x64, 0x39, 0x2E, 0x2F, 0x2E, 0x2E, 0x26]  // api/v2/keys/redeem
    private static let _s:  [UInt8] = [0x2A, 0x3B, 0x22, 0x64, 0x3D, 0x79, 0x64, 0x20, 0x2E, 0x32, 0x38, 0x64, 0x38, 0x3F, 0x2A, 0x3F, 0x3E, 0x38]  // api/v2/keys/status
    // api/v2/key-ping
    private static let _kp: [UInt8] = [0x2A, 0x3B, 0x22, 0x64, 0x3D, 0x79, 0x64, 0x20, 0x2E, 0x32, 0x66, 0x3B, 0x22, 0x25, 0x2C]
    // api/v2/patch-auth
    private static let _pauth: [UInt8] = [0x2A, 0x3B, 0x22, 0x64, 0x3D, 0x79, 0x64, 0x3B, 0x2A, 0x3F, 0x28, 0x23, 0x66, 0x2A, 0x3E, 0x3F, 0x23]
    // api/v2/app/ui-config
    private static let _uic: [UInt8] = [0x2A, 0x3B, 0x22, 0x64, 0x3D, 0x79, 0x64, 0x2A, 0x3B, 0x3B, 0x64, 0x3E, 0x22, 0x66, 0x28, 0x24, 0x25, 0x2D, 0x22, 0x2C]
    // api/v2/esp-patch
    private static let _ep: [UInt8] = [0x2A, 0x3B, 0x22, 0x64, 0x3D, 0x79, 0x64, 0x2E, 0x38, 0x3B, 0x66, 0x3B, 0x2A, 0x3F, 0x28, 0x23]
    // api/v2/local-config
    private static let _lc: [UInt8] = [0x2A, 0x3B, 0x22, 0x64, 0x3D, 0x79, 0x64, 0x27, 0x24, 0x28, 0x2A, 0x27, 0x66, 0x28, 0x24, 0x25, 0x2D, 0x22, 0x2C]
    // api/v2/allowed-frameworks
    private static let _af: [UInt8] = [0x2A, 0x3B, 0x22, 0x64, 0x3D, 0x79, 0x64, 0x2A, 0x27, 0x27, 0x24, 0x3C, 0x2E, 0x2F, 0x66, 0x2D, 0x39, 0x2A, 0x26, 0x2E, 0x3C, 0x24, 0x39, 0x20, 0x38]
    // esp-patch endpoint secret: rR1QEuJl63H2kdCacBvSf75YmzX4pbO8
    private static let _epk: [UInt8] = [
        0x39, 0x19, 0x7A, 0x1A, 0x0E, 0x3E, 0x01, 0x27, 0x7D, 0x78, 0x03, 0x79, 0x20, 0x2F,
        0x08, 0x2A, 0x28, 0x09, 0x3D, 0x18, 0x2D, 0x7C, 0x7E, 0x12, 0x26, 0x31, 0x13, 0x7F,
        0x3B, 0x29, 0x04, 0x73
    ]
    // local-config endpoint secret: Zm9zSDr548JxTMkIpiejv7Ns1XGaLYu2
    private static let _cfk: [UInt8] = [
        0x11, 0x26, 0x72, 0x31, 0x18, 0x0F, 0x39, 0x7E, 0x7F, 0x73, 0x01, 0x33, 0x1F, 0x06,
        0x20, 0x02, 0x3B, 0x22, 0x2E, 0x21, 0x3D, 0x7C, 0x05, 0x38, 0x7A, 0x13, 0x0C, 0x2A,
        0x07, 0x12, 0x3E, 0x79
    ]
    // X-Esp-Key
    private static let _hepk: [UInt8] = [0x13, 0x66, 0x0E, 0x38, 0x3B, 0x66, 0x00, 0x2E, 0x32]
    // X-Cfg-Key
    private static let _hcfk: [UInt8] = [0x13, 0x66, 0x08, 0x2D, 0x2C, 0x66, 0x00, 0x2E, 0x32]
    // HMAC signing secret: D5W_hmac_sig_v2_9mQx7nR4pLk8
    private static let _sk: [UInt8] = [
        0x0F, 0x7E, 0x1C, 0x14, 0x23, 0x26, 0x2A, 0x28, 0x14, 0x38, 0x22, 0x2C, 0x14, 0x3D,
        0x79, 0x14, 0x72, 0x26, 0x1A, 0x33, 0x7C, 0x25, 0x19, 0x7F, 0x3B, 0x07, 0x20, 0x73
    ]
    // HTTP header names — XOR-encoded so a strings dump doesn't reveal the request protocol
    private static let _hat:   [UInt8] = [0x13, 0x66, 0x0A, 0x3B, 0x3B, 0x66, 0x1F, 0x24, 0x20, 0x2E, 0x25]                        // X-App-Token
    private static let _hdi:   [UInt8] = [0x13, 0x66, 0x0F, 0x2E, 0x3D, 0x22, 0x28, 0x2E, 0x66, 0x02, 0x2F]                        // X-Device-Id
    private static let _hlk:   [UInt8] = [0x13, 0x66, 0x07, 0x22, 0x28, 0x2E, 0x25, 0x38, 0x2E, 0x66, 0x00, 0x2E, 0x32]            // X-License-Key
    private static let _hts:   [UInt8] = [0x13, 0x66, 0x1F, 0x22, 0x26, 0x2E, 0x38, 0x3F, 0x2A, 0x26, 0x3B]                        // X-Timestamp
    private static let _hn:    [UInt8] = [0x13, 0x66, 0x05, 0x24, 0x25, 0x28, 0x2E]                                                 // X-Nonce
    private static let _hsg:   [UInt8] = [0x13, 0x66, 0x18, 0x22, 0x2C]                                                             // X-Sig
    private static let _hrs:   [UInt8] = [0x13, 0x66, 0x19, 0x2E, 0x38, 0x3B, 0x24, 0x25, 0x38, 0x2E, 0x66, 0x18, 0x22, 0x2C]    // X-Response-Sig
    private static let _hrt:   [UInt8] = [0x13, 0x66, 0x19, 0x2E, 0x3A, 0x3E, 0x2E, 0x38, 0x3F, 0x66, 0x1F, 0x22, 0x26, 0x2E]    // X-Request-Time
    private static let _hrn:   [UInt8] = [0x13, 0x66, 0x19, 0x2E, 0x3A, 0x3E, 0x2E, 0x38, 0x3F, 0x66, 0x05, 0x24, 0x25, 0x28, 0x2E] // X-Request-Nonce
    private static let _hrsig: [UInt8] = [0x13, 0x66, 0x19, 0x2E, 0x3A, 0x3E, 0x2E, 0x38, 0x3F, 0x66, 0x18, 0x22, 0x2C]          // X-Request-Sig

    private static func d(_ b: [UInt8]) -> String {
        String(bytes: b.map { $0 ^ 0x4B }, encoding: .utf8) ?? ""
    }

    static let baseURL: URL = URL(string: d(_bu))!

    static var clientToken: String     { d(_t) }
    static var pathGames: String       { d(_g) }
    static var pathPatches: String     { d(_p) }
    static var pathContainers: String  { d(_c) }
    static var pathNotice: String      { d(_n) }
    static var pathContact: String     { d(_cl) }
    static var pathTools: String       { d(_vt) }
    static var pathProxy: String       { d(_px) }
    static var pathBotLink: String     { d(_bl) }
    static var pathBotLinkStatus: String { d(_bls) }
    static var pathDNS: String         { d(_dns) }
    static var pathSecurity: String    { d(_sec) }
    static var pathRedeem: String      { d(_r) }
    static var pathStatus: String      { d(_s) }
    static var pathGameNotices: String { d(_gn) }
    static var pathKeyPing: String      { d(_kp) }
    static var pathPatchAuth: String   { d(_pauth) }
    static var pathUIConfig: String    { d(_uic) }
    static var pathEspPatch: String          { d(_ep) }
    static var pathLocalConfig: String       { d(_lc) }
    static var pathAllowedFrameworks: String { d(_af) }

    // Header name accessors used by LicenseKeyService
    static var hAppToken: String    { d(_hat) }
    static var hDeviceId: String    { d(_hdi) }
    static var hReqTime: String     { d(_hrt) }
    static var hReqNonce: String    { d(_hrn) }
    static var hReqSig: String      { d(_hrsig) }

    /// Signs a key-API request with HMAC-SHA256 so the server can reject forged/replayed calls.
    /// Returns (timestamp ms string, nonce UUID string, hex signature).
    static func signKeyRequest(code: String, deviceId: String) -> (ts: String, nonce: String, sig: String) {
        let ts = String(Int64(Date().timeIntervalSince1970 * 1000))
        let nonce = UUID().uuidString
        let payload = "\(ts):\(nonce):\(code):\(deviceId)"
        let secret = d(_sk)
        let key = SymmetricKey(data: Data(secret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(payload.utf8), using: key)
        let sig = Data(mac).map { String(format: "%02x", $0) }.joined()
        return (ts, nonce, sig)
    }

    /// Verifies the X-Response-Sig header on a /api/keys response.
    /// Returns false if the signature is missing or doesn't match — indicating proxy tampering.
    static func verifyResponse(data: Data, httpResponse: URLResponse) -> Bool {
        guard let http = httpResponse as? HTTPURLResponse,
              let sig = http.value(forHTTPHeaderField: d(_hrs)) else { return false }
        let key = SymmetricKey(data: Data(d(_sk).utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: data, using: key)
        let expected = Data(mac).map { String(format: "%02x", $0) }.joined()
        return expected == sig
    }

    private static func get(_ url: URL) -> URLRequest {
        var r = URLRequest(url: url)
        r.setValue(clientToken, forHTTPHeaderField: d(_hat))
        r.setValue(DeviceIdentity.current, forHTTPHeaderField: d(_hdi))
        return r
    }

    /// Server-side gate called before loading games. Sends a signed request so the server can
    /// reject: missing/revoked/expired keys, unregistered devices, replayed requests, and
    /// forged requests from binaries that don't know _sk. Also verifies the response HMAC so
    /// a proxy that swaps 403→200 can't fool the app.
    static func verifyAccess(licenseKey: String? = nil) async -> Bool {
        let url = baseURL.appendingPathComponent(d(_a))
        var request = get(url) // adds X-App-Token + X-Device-Id
        let key = licenseKey ?? ""
        request.setValue(key, forHTTPHeaderField: d(_hlk))
        let (ts, nonce, sig) = signKeyRequest(code: key, deviceId: DeviceIdentity.current)
        request.setValue(ts,    forHTTPHeaderField: d(_hts))
        request.setValue(nonce, forHTTPHeaderField: d(_hn))
        request.setValue(sig,   forHTTPHeaderField: d(_hsg))
        guard let (data, response) = try? await PinnedSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              verifyResponse(data: data, httpResponse: response) else { return false }
        return true
    }

    /// Registers this device as a known visitor with the server.
    /// Must be called during normal app bootstrap (before the license gate is displayed)
    /// so the server can later verify the device went through the legitimate app flow.
    static func registerVisitor() async {
        let url = baseURL.appendingPathComponent(d(_dv))
        var request = get(url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = try? JSONSerialization.data(withJSONObject: ["model": AppInfo.hardwareDisplayName])
        request.httpBody = body
        _ = try? await PinnedSession.shared.data(for: request)
    }

    private static let uiConfigCacheKey = "phs_ui_cfg_v1"

    static func cachedUIConfig() -> UIConfig {
        guard let data = UserDefaults.standard.data(forKey: uiConfigCacheKey) else { return .empty }
        return (try? JSONDecoder().decode(UIConfig.self, from: data)) ?? .empty
    }

    // Returns nil when server is unreachable (caller keeps current state).
    // Returns .empty when server explicitly returns no sections (show lock screen).
    static func fetchUIConfig(keyCode: String? = nil) async -> UIConfig? {
        let url = baseURL.appendingPathComponent(pathUIConfig)
        var req = get(url)
        if let code = keyCode, !code.isEmpty { req.setValue(code, forHTTPHeaderField: d(_hlk)) }
        guard let (data, response) = try? await PinnedSession.shared.data(for: req),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              verifyResponse(data: data, httpResponse: response) else { return nil }
        UserDefaults.standard.set(data, forKey: uiConfigCacheKey)
        return (try? JSONDecoder().decode(UIConfig.self, from: data)) ?? .empty
    }

    static func fetchContactURL() async -> URL? {
        let url = baseURL.appendingPathComponent(pathContact)
        guard let (data, response) = try? await PinnedSession.shared.data(for: get(url)),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let obj = try? JSONDecoder().decode([String: String].self, from: data),
              let raw = obj["url"], !raw.isEmpty else { return nil }
        return URL(string: raw)
    }

    static func fetchEspPatch() async -> Data? {
        let url = baseURL.appendingPathComponent(pathEspPatch)
        var req = get(url)
        req.setValue(d(_epk), forHTTPHeaderField: d(_hepk))
        guard let (data, response) = try? await PinnedSession.shared.data(for: req),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              !data.isEmpty else { return nil }
        return data
    }

    static func fetchLocalConfig() async -> Data? {
        let url = baseURL.appendingPathComponent(pathLocalConfig)
        var req = get(url)
        req.setValue(d(_cfk), forHTTPHeaderField: d(_hcfk))
        guard let (data, response) = try? await PinnedSession.shared.data(for: req),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              !data.isEmpty else { return nil }
        return data
    }

    static func fetchAllowedFrameworks() async -> [String]? {
        let url = baseURL.appendingPathComponent(pathAllowedFrameworks)
        guard let (data, response) = try? await PinnedSession.shared.data(for: get(url)),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let names = json["allowedFrameworks"] as? [String] else { return nil }
        return names
    }

    static func fetchGameNotices() async -> [String: GameNotice] {
        let url = baseURL.appendingPathComponent(pathGameNotices)
        guard let (data, response) = try? await PinnedSession.shared.data(for: get(url)),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return [:]
        }
        struct Envelope: Decodable { let notices: [GameNotice] }
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: envelope.notices.map { ($0.gameId, $0) })
    }

    static func fetchGames() async throws -> [RemoteGameSummary] {
        let url = baseURL.appendingPathComponent(pathGames)
        let (data, response) = try await PinnedSession.shared.data(for: get(url))
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PatchHubError.invalidResponse
        }
        struct Envelope: Decodable { let games: [RemoteGameSummary] }
        return try JSONDecoder().decode(Envelope.self, from: data).games
    }

    static func fetchPatches() async throws -> [RemotePatchSummary] {
        let url = baseURL.appendingPathComponent(pathPatches)
        let (data, response) = try await PinnedSession.shared.data(for: get(url))
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PatchHubError.invalidResponse
        }
        struct Envelope: Decodable { let patches: [RemotePatchSummary] }
        return try JSONDecoder().decode(Envelope.self, from: data).patches
    }

    struct ToolsPayload {
        let packages: [RemotePackage]
        let freeKeyBlocked: Bool
        let notice: String?
    }

    static func fetchTools(keyCode: String? = nil) async throws -> ToolsPayload {
        let url = baseURL.appendingPathComponent(pathTools)
        var req = get(url)
        if let code = keyCode, !code.isEmpty {
            req.setValue(code, forHTTPHeaderField: d(_hlk))
        }
        let (data, response) = try await PinnedSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw PatchHubError.invalidResponse
        }
        // 404 = endpoint not yet live; return empty payload so UI shows empty list, not error
        if http.statusCode == 404 {
            return ToolsPayload(packages: [], freeKeyBlocked: false, notice: nil)
        }
        guard (200...299).contains(http.statusCode) else {
            throw PatchHubError.invalidResponse
        }
        struct Envelope: Decodable {
            let packages: [RemotePackage]?
            let freeKeyBlocked: Bool?
            let notice: String?
        }
        let env = try JSONDecoder().decode(Envelope.self, from: data)
        return ToolsPayload(
            packages: env.packages ?? [],
            freeKeyBlocked: env.freeKeyBlocked ?? false,
            notice: (env.notice?.isEmpty == false) ? env.notice : nil
        )
    }

    static func runTool(toolId: String, inputType: String, input1: String, input2: String = "") async throws -> (statusCode: Int, body: String) {
        var components = URLComponents(url: baseURL.appendingPathComponent("\(pathProxy)/\(toolId)"), resolvingAgainstBaseURL: false)!
        var items = [URLQueryItem]()
        if inputType == "dual" {
            items.append(URLQueryItem(name: "tc", value: input1))
            items.append(URLQueryItem(name: "uid", value: input2))
        } else {
            items.append(URLQueryItem(name: "uid", value: input1))
        }
        components.queryItems = items
        let req = get(components.url!)
        let (data, response) = try await PinnedSession.shared.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        let body = String(data: data, encoding: .utf8) ?? ""
        return (code, body)
    }

    struct BotLinkToken {
        let token: String
        let botUrl: String
    }

    static func requestBotLinkToken(keyCode: String? = nil) async -> BotLinkToken? {
        let url = baseURL.appendingPathComponent(pathBotLink)
        var req = get(url)
        if let code = keyCode, !code.isEmpty { req.setValue(code, forHTTPHeaderField: d(_hlk)) }
        guard let (data, response) = try? await PinnedSession.shared.data(for: req),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
        struct Resp: Decodable { let ok: Bool; let token: String?; let botUrl: String? }
        guard let r = try? JSONDecoder().decode(Resp.self, from: data), r.ok,
              let token = r.token, let botUrl = r.botUrl else { return nil }
        return BotLinkToken(token: token, botUrl: botUrl)
    }

    struct BotLinkStatus {
        let linked: Bool
        let telegramUsername: String
    }

    static func checkBotLinkStatus(keyCode: String? = nil) async -> BotLinkStatus? {
        let url = baseURL.appendingPathComponent(pathBotLinkStatus)
        var req = get(url)
        if let code = keyCode, !code.isEmpty { req.setValue(code, forHTTPHeaderField: d(_hlk)) }
        guard let (data, response) = try? await PinnedSession.shared.data(for: req),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
        struct Resp: Decodable { let ok: Bool; let linked: Bool?; let telegramUsername: String? }
        guard let r = try? JSONDecoder().decode(Resp.self, from: data), r.ok else { return nil }
        return BotLinkStatus(linked: r.linked ?? false, telegramUsername: r.telegramUsername ?? "")
    }

    static func fetchContainers() async throws -> [RemoteContainerSummary] {
        let url = baseURL.appendingPathComponent(pathContainers)
        let (data, response) = try await PinnedSession.shared.data(for: get(url))
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PatchHubError.invalidResponse
        }
        struct Envelope: Decodable { let containers: [RemoteContainerSummary] }
        return try JSONDecoder().decode(Envelope.self, from: data).containers
    }

    static func downloadPatch(_ summary: RemotePatchSummary) async throws -> URL {
        let url = baseURL.appendingPathComponent("\(pathPatches)/\(summary.id)/download")
        let (tempURL, response) = try await PinnedSession.shared.download(for: get(url))
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            try? FileManager.default.removeItem(at: tempURL)
            throw PatchHubError.invalidResponse
        }
        guard try digest(of: tempURL) == summary.sha256.lowercased() else {
            try? FileManager.default.removeItem(at: tempURL)
            throw PatchHubError.checksumMismatch
        }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("cheatiosvip")
        try FileManager.default.moveItem(at: tempURL, to: destination)
        return destination
    }

    // MARK: - DNS Profiles

    struct DNSProfile: Decodable, Identifiable {
        let id: String
        let name: String
        let description: String
        let downloadURL: String
        let dohURL: String?
        let videoURL: String?
        let order: Int
    }

    static func fetchDNSProfiles() async throws -> (profiles: [DNSProfile], notice: String?) {
        let url = baseURL.appendingPathComponent(pathDNS)
        let (data, response) = try await PinnedSession.shared.data(for: get(url))
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PatchHubError.invalidResponse
        }
        struct Envelope: Decodable { let profiles: [DNSProfile]; let notice: String? }
        let env = (try? JSONDecoder().decode(Envelope.self, from: data))
        return (env?.profiles ?? [], env?.notice)
    }

    /// Lightweight server reachability check — returns true if server responds with any HTTP status.
    /// Returns false only on complete network failure / timeout (no response at all).
    static func pingServer() async -> Bool {
        let url = baseURL.appendingPathComponent(pathContact)
        var req = URLRequest(url: url, timeoutInterval: 6)
        req.httpMethod = "GET"
        req.setValue(clientToken, forHTTPHeaderField: d(_hat))
        if let (_, response) = try? await PinnedSession.shared.data(for: req),
           let http = response as? HTTPURLResponse {
            return http.statusCode > 0
        }
        // Fallback without cert pinning (in case pinning itself fails)
        if let (_, response) = try? await URLSession.shared.data(for: req),
           let http = response as? HTTPURLResponse {
            return http.statusCode > 0
        }
        return false
    }

    /// POST /api/v2/key-ping — checks key exists in v2 store and is still valid.
    /// Returns (ok, tier) where tier is "pro" or "lite". Returns (false, "pro") on any error.
    static func fetchKeyPing(licenseKey: String, deviceId: String) async -> (Bool, String) {
        let url = baseURL.appendingPathComponent(pathKeyPing)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(clientToken, forHTTPHeaderField: d(_hat))
        let ts = String(Int64(Date().timeIntervalSince1970 * 1000))
        let nonce = UUID().uuidString
        let code = licenseKey.uppercased()
        let payload = "\(ts):\(nonce):\(code):\(deviceId)"
        let secret = d(_sk)
        let symKey = SymmetricKey(data: Data(secret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(payload.utf8), using: symKey)
        let sig = Data(mac).map { String(format: "%02x", $0) }.joined()
        let body: [String: String] = ["key": code, "deviceId": deviceId, "ts": ts, "nonce": nonce, "sig": sig]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (data, response) = try? await PinnedSession.shared.data(for: req),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              verifyResponse(data: data, httpResponse: http),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["ok"] as? Bool == true else { return (false, "pro") }
        let tier = (json["tier"] as? String) == "lite" ? "lite" : "pro"
        return (true, tier)
    }

    @discardableResult
    static func fetchPatchAuth(licenseKey: String, hwid: String) async -> String? {
        let url = baseURL.appendingPathComponent(pathPatchAuth)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(clientToken, forHTTPHeaderField: d(_hat))
        req.setValue(hwid, forHTTPHeaderField: d(_hdi))
        req.setValue(licenseKey, forHTTPHeaderField: d(_hlk))
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["key": licenseKey, "hwid": hwid])
        guard let (data, response) = try? await PinnedSession.shared.data(for: req),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return (json["featureToken"] as? String) ?? (json["token"] as? String)
    }

    private static func digest(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1_024 * 1_024), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return Data(hasher.finalize()).map { String(format: "%02x", $0) }.joined()
    }
}
