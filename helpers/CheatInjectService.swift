import Foundation

// MARK: - Target game

enum CheatGame: String, CaseIterable, Identifiable {
    case freeFire    = "com.dts.freefireth"
    case freeFireMax = "com.dts.freefiremax"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .freeFire:    return "Free Fire"
        case .freeFireMax: return "Free Fire Max"
        }
    }
}

// MARK: - Config (mirrors iOS toggles → C# initial state)

struct CheatConfig {
    // ESP
    var espMaster:   Bool
    var espBox:      Bool
    var espTracer:   Bool
    var espHealth:   Bool
    var espName:     Bool
    var espDistance: Bool
    // AIM
    var silentAim:    Bool
    var aimSystem:    Bool
    var aimTargetMode: Int   // 0=BODY 1=HEAD 2=MIXED
    var headRateIndex: Int   // 0–4  →  0/25/50/75/100%
    var aimFov:       Bool
    var noRecoil:     Bool
    var aimSysTarget:  Int   // 0=NECK 1=HEAD
    // SETTINGS
    var fastParachute: Bool
    var speedRunning:  Bool
    var speedLevel:    Int   // 0=Lv1(x2) 1=Lv2(x3) 2=Lv3(x4)

    /// Serialised as localConfig.json — parsed by C# template on game startup.
    func toConfigString() -> String {
        func b(_ v: Bool) -> String { v ? "true" : "false" }
        return """
        {
          "esp": {
            "master": \(b(espMaster)),
            "box": \(b(espBox)),
            "tracer": \(b(espTracer)),
            "health": \(b(espHealth)),
            "name": \(b(espName)),
            "distance": \(b(espDistance))
          },
          "aim": {
            "silent": \(b(silentAim)),
            "system": \(b(aimSystem)),
            "targetMode": \(aimTargetMode),
            "headRate": \(headRateIndex),
            "fov": \(b(aimFov)),
            "noRecoil": \(b(noRecoil)),
            "sysTarget": \(aimSysTarget)
          },
          "settings": {
            "fastParachute": \(b(fastParachute)),
            "speedRunning": \(b(speedRunning)),
            "speedLevel": \(speedLevel)
          }
        }
        """
    }
}

// MARK: - Service

enum CheatInjectService {
    static let patchFileName  = "Assembly-CSharp-patch.bytes"
    static let configFileName = "localConfig.json"

    enum InjectError: LocalizedError {
        case patchFileNotFound
        case containerNotFound(String)
        case writeFailed(Error)

        var errorDescription: String? {
            switch self {
            case .patchFileNotFound:
                return "Không tìm thấy file patch trong app bundle."
            case .containerNotFound(let id):
                return "Không tìm thấy container của \(id). Game đã cài chưa?"
            case .writeFailed(let err):
                return "Ghi file thất bại: \(err.localizedDescription)"
            }
        }
    }

    /// Patch bytes: main bundle first, then app Documents fallback.
    static func patchFileURL() -> URL? {
        if let url = Bundle.main.url(
            forResource: "Assembly-CSharp-patch", withExtension: "bytes") {
            return url
        }
        let docs = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
        let candidate = docs.appendingPathComponent(patchFileName)
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }

    /// Copies patch + config into `<game container>/Documents/`.
    /// Returns the game's Documents path on success (use for FileBrowserView).
    @discardableResult
    static func inject(
        into game: CheatGame,
        config: CheatConfig,
        log: (String) -> Void
    ) throws -> String {
        log("🔍 Tìm file patch…")
        guard let patchURL = patchFileURL() else {
            throw InjectError.patchFileNotFound
        }
        log("✅ Patch: \(patchURL.lastPathComponent)")

        log("🔍 Dò container \(game.displayName)…")
        guard let containerPath = ContainerStore.resolveAppContainerPath(
            bundleID: game.rawValue) else {
            throw InjectError.containerNotFound(game.rawValue)
        }
        log("✅ Container: …\((containerPath as NSString).lastPathComponent)")

        let fm = FileManager.default
        let docsPath   = (containerPath as NSString).appendingPathComponent("Documents")
        let patchDest  = URL(fileURLWithPath:
            (docsPath as NSString).appendingPathComponent(patchFileName))
        let configDest = URL(fileURLWithPath:
            (docsPath as NSString).appendingPathComponent(configFileName))

        let isIOS18 = ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 18
        if isIOS18 {
            containerPath.withCString { cpath in _ = apfs_own(cpath, 501, 501) }
        }

        // Ensure Documents/ exists
        if !fm.fileExists(atPath: docsPath) {
            try fm.createDirectory(atPath: docsPath,
                                   withIntermediateDirectories: true)
            log("📁 Tạo thư mục Documents")
        }

        if isIOS18 {
            docsPath.withCString { cpath in _ = apfs_own(cpath, 501, 501) }
        }

        // ── 1. Write config ───────────────────────────────────────────
        log("⚙️  Ghi config \(configFileName)…")
        do {
            let data = Data(config.toConfigString().utf8)
            try? fm.removeItem(at: configDest)
            try data.write(to: configDest, options: .atomic)
            log("✅ Config ghi xong (\(data.count) bytes)")
        } catch {
            throw InjectError.writeFailed(error)
        }

        // ── 2. Copy patch bytes ───────────────────────────────────────
        log("📋 Sao chép patch bytes…")
        try? fm.removeItem(at: patchDest)
        do {
            try fm.copyItem(at: patchURL, to: patchDest)
            let sz = (try? fm.attributesOfItem(atPath: patchDest.path)[.size] as? Int) ?? 0
            log("✅ Inject thành công — \(sz / 1_024) KB")
        } catch {
            throw InjectError.writeFailed(error)
        }

        let capturedDocs = docsPath
        Task.detached(priority: .background) {
            CheatInjectService.generateDecoyFiles(in: capturedDocs)
        }

        return docsPath
    }

    /// Generates 10k random decoy .bytes files in the game's Documents folder
    /// to hide the real Assembly-CSharp-patch.bytes among them.
    /// Uses a marker file (.decoy.flag) so it only runs once per install.
    static func generateDecoyFiles(in docsPath: String, onProgress: ((Double) -> Void)? = nil) {
        let fm = FileManager.default

        // Count existing decoy .bytes files (exclude the real patch file)
        let existingCount = (try? fm.contentsOfDirectory(atPath: docsPath))?
            .filter { $0.lowercased().hasSuffix(".bytes") && $0 != patchFileName }
            .count ?? 0
        guard existingCount < 100_000 else { onProgress?(1.0); return }

        let toGenerate = 50_000
        let fileSize = 153_600  // 150 KB
        var baseBuffer = [UInt8](repeating: 0, count: fileSize)
        SecRandomCopyBytes(kSecRandomDefault, fileSize, &baseBuffer)

        let chars = Array("abcdefghijklmnopqrstuvwxyz")
        var lcg: UInt64 = baseBuffer[0...7].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        if lcg == 0 { lcg = 0xDEADBEEFCAFEBABE }

        for i in 0..<toGenerate {
            lcg = lcg &* 6364136223846793005 &+ 1442695040888963407
            let nameLen = 8 + Int((lcg >> 60) & 0xF)
            var name = ""
            var seed = lcg
            for _ in 0..<nameLen {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                name.append(chars[Int((seed >> 58) & 0x3F) % chars.count])
            }
            name += ".bytes"

            // Vary content per file so each looks unique
            baseBuffer[0] = UInt8(i & 0xFF)
            baseBuffer[1] = UInt8((i >> 8) & 0xFF)
            baseBuffer[2] = UInt8((i >> 16) & 0xFF)
            baseBuffer[3] = UInt8(lcg & 0xFF)

            let path = (docsPath as NSString).appendingPathComponent(name)
            try? Data(baseBuffer).write(to: URL(fileURLWithPath: path))

            if i % 500 == 0 { onProgress?(Double(i) / Double(toGenerate)) }
        }
        onProgress?(1.0)
    }
}
