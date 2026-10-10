import Foundation
import Security

@MainActor
final class LicenseGateStore: ObservableObject {
    // Backing store: XOR'd bytes + parity check so a simple bool-flip or hook
    // has to understand the encoding to produce a valid unlocked state.
    // Layout: [b0, b1, b2, b3] where bN = (unlocked ? (0xA5 ^ salt[N]) : salt[N])
    // Parity byte b3 = b0 ^ b1 ^ b2 ^ 0xC3 (must match or treated as locked).
    private static let _salt: [UInt8] = [0x37, 0x8E, 0x5D, 0x1A]
    private var _unlockBuf: [UInt8] = LicenseGateStore._lockedBuf()
    private static func _lockedBuf() -> [UInt8] {
        let s = _salt; return [s[0], s[1], s[2], s[0] ^ s[1] ^ s[2] ^ 0xC3]
    }
    private static func _unlockedBuf() -> [UInt8] {
        let s = _salt
        let b0: UInt8 = 0xA5 ^ s[0]; let b1: UInt8 = 0xA5 ^ s[1]; let b2: UInt8 = 0xA5 ^ s[2]
        return [b0, b1, b2, b0 ^ b1 ^ b2 ^ 0xC3]
    }

    @Published private(set) var isUnlocked: Bool = false {
        didSet { _unlockBuf = isUnlocked ? Self._unlockedBuf() : Self._lockedBuf() }
    }
    // Call this in views instead of reading isUnlocked directly for extra verification.
    var isReallyUnlocked: Bool {
        let s = Self._salt
        guard _unlockBuf.count == 4 else { return false }
        let parity = _unlockBuf[0] ^ _unlockBuf[1] ^ _unlockBuf[2] ^ 0xC3
        guard parity == _unlockBuf[3] else { return false }  // tampered
        return _unlockBuf[0] == (0xA5 ^ s[0])
    }

    // Anti-bypass server gate — set ONLY by a real /api/v2/key-ping response.
    // Same XOR+parity encoding as _unlockBuf so a memory hook must understand the scheme.
    private static let _gateSalt: [UInt8] = [0x4C, 0xB7, 0x23, 0xE9]
    private var _gateBuf: [UInt8] = LicenseGateStore._closedGateBuf()
    private static func _closedGateBuf() -> [UInt8] {
        let s = _gateSalt; return [s[0], s[1], s[2], s[0] ^ s[1] ^ s[2] ^ 0xD6]
    }
    private static func _openGateBuf() -> [UInt8] {
        let s = _gateSalt
        let b0: UInt8 = 0x5E ^ s[0]; let b1: UInt8 = 0x5E ^ s[1]; let b2: UInt8 = 0x5E ^ s[2]
        return [b0, b1, b2, b0 ^ b1 ^ b2 ^ 0xD6]
    }

    func openServerGate() {
        _gateBuf = Self._openGateBuf()
    }

    var isServerGateOpen: Bool {
        let s = Self._gateSalt
        guard _gateBuf.count == 4 else { return false }
        let parity = _gateBuf[0] ^ _gateBuf[1] ^ _gateBuf[2] ^ 0xD6
        guard parity == _gateBuf[3] else { return false }
        return _gateBuf[0] == (0x5E ^ s[0])
    }

    @Published private(set) var isChecking = true
    @Published private(set) var expiresAt: Date?
    @Published private(set) var licenseDevices: [LicenseDeviceEntry] = []
    @Published private(set) var keySource: String = "admin"  // "admin" | "seller" | "getkey"
    @Published private(set) var isSellerVip: Bool = false

    var isAdminKey: Bool { keySource == "admin" }
    var isVipEligible: Bool { isAdminKey || isSellerVip }
    @Published var errorMessage: String?
    @Published var activationToast: ToastMessage?

    private static let kcService = "com.cheatiosvip.license"
    private static let kcAccount = "key-code"

    private(set) var storedKeyCode: String? {
        get { Self.keychainLoad() }
        set {
            if let value = newValue { Self.keychainSave(value) }
            else { Self.keychainDelete() }
        }
    }

    nonisolated static var storedKeyCode: String? { keychainLoad() }

    nonisolated private static func keychainLoad() -> String? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: kcService,
            kSecAttrAccount as String: kcAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var ref: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &ref) == errSecSuccess,
              let data = ref as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func keychainSave(_ value: String) {
        let data = Data(value.utf8)
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: kcService,
            kSecAttrAccount as String: kcAccount
        ]
        let attrs: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        if SecItemUpdate(q as CFDictionary, attrs as CFDictionary) == errSecItemNotFound {
            var item = q; attrs.forEach { item[$0.key] = $0.value }
            SecItemAdd(item as CFDictionary, nil)
        }
    }

    private static func keychainDelete() {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: kcService,
            kSecAttrAccount as String: kcAccount
        ]
        SecItemDelete(q as CFDictionary)
    }

    var maskedKeyCode: String {
        guard let code = storedKeyCode else { return "" }
        guard code.count > 8 else { return code }
        return "\(code.prefix(4))••••\(code.suffix(4))"
    }

    func remainingTimeText(language: AppLanguage) -> String {
        guard let expiresAt else { return "" }
        let seconds = expiresAt.timeIntervalSinceNow
        guard seconds > 0 else { return language.text("license.expired") }
        let days = Int(seconds) / 86400
        let hours = (Int(seconds) % 86400) / 3600
        return language.text("license.remaining", Int64(days), Int64(hours))
    }

    func bootstrap() async {
        isChecking = true
        defer { isChecking = false }
        guard let code = storedKeyCode, !code.isEmpty else {
            await PatchHubService.registerVisitor()
            isUnlocked = false
            return
        }
        // registerVisitor and refreshStatus are independent — run in parallel.
        // registerVisitor must finish before any requireRegisteredDevice endpoint
        // is called, but bootstrap() is awaited before the home view appears,
        // so both complete before any content request fires.
        async let visitor: () = PatchHubService.registerVisitor()
        async let status: () = refreshStatus(code: code)
        _ = await (visitor, status)
    }

    func revalidateIfNeeded() async {
        guard isUnlocked, let code = storedKeyCode else { return }
        await refreshStatus(code: code)
    }

    @discardableResult
    func redeem(code rawCode: String) async -> Bool {
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        errorMessage = nil
        do {
            let result = try await LicenseKeyService.redeem(
                code: code,
                deviceId: DeviceIdentity.current,
                deviceModel: AppInfo.hardwareDisplayName
            )
            storedKeyCode = code
            expiresAt = result.expiresAt
            licenseDevices = result.devices
            keySource = result.keySource
            isSellerVip = result.sellerVip
            isUnlocked = true
            let language = AppLanguage.vietnamese
            let detail = language.text("license.activated_detail", AppInfo.hardwareDisplayName, remainingTimeText(language: language))
            activationToast = ToastMessage(text: "\(language.text("license.activated_success"))\n\(detail)")
            return true
        } catch let error as LicenseKeyError {
            errorMessage = AppLanguage.vietnamese.text(error.localizationKey)
            return false
        } catch {
            errorMessage = AppLanguage.vietnamese.text(LicenseKeyError.network.localizationKey)
            return false
        }
    }

    func changeKey() {
        storedKeyCode = nil
        expiresAt = nil
        licenseDevices = []
        keySource = "admin"
        isSellerVip = false
        isUnlocked = false
        errorMessage = nil
        _gateBuf = Self._closedGateBuf()
    }

    private func refreshStatus(code: String) async {
        do {
            let result = try await LicenseKeyService.status(code: code, deviceId: DeviceIdentity.current)
            expiresAt = result.expiresAt
            licenseDevices = result.devices
            keySource = result.keySource
            isSellerVip = result.sellerVip
            isUnlocked = true
        } catch LicenseKeyError.network {
            // Connectivity issue only — keep whatever unlocked state we already had.
        } catch LicenseKeyError.expired {
            changeKey()
        } catch {
            isUnlocked = false
        }
    }
}
