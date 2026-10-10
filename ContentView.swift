import SwiftUI

struct ContentView: View {
    @StateObject private var licenseGate = LicenseGateStore()
    @State private var isCheckingMaintenance = true
    @State private var maintenanceNotice: MaintenanceNotice?
    @State private var blockingAnnouncement: Announcement?
    @State private var isTampered = false
    @State private var isJailbroken = false
    @State private var showSplash = true
    @State private var keyVerified = false
    @State private var serverUnreachable = false
    @AppStorage("shown_announcement_ids") private var shownIDsRaw = ""
    @AppStorage("fakeAppEnabled") private var fakeAppEnabled: Bool = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            if fakeAppEnabled {
                FlappyBirdGameView()
                    .task { await fakeStartupCheck() }
            } else {
                mainContent
                if let ann = blockingAnnouncement {
                    AnnouncementBlockView(announcement: ann) {
                        withAnimation(.easeInOut(duration: 0.3)) { blockingAnnouncement = nil }
                    }
                    .zIndex(998)
                    .transition(.opacity)
                }
                if showSplash {
                    SplashScreenView {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showSplash = false
                        }
                    }
                    .zIndex(999)
                    .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showSplash)
        .animation(.easeInOut(duration: 0.3), value: blockingAnnouncement == nil)
    }

    @ViewBuilder
    private var mainContent: some View {
        Group {
            if serverUnreachable {
                ServerBlockView()
            } else if isTampered {
                TamperBlockView()
            } else if isJailbroken {
                JailbreakBlockView(onRecheck: { isJailbroken = JailbreakDetector.isJailbroken() })
            } else if isCheckingMaintenance || licenseGate.isChecking {
                ZStack {
                    TechBackground()
                    ProgressView()
                }
                .preferredColorScheme(.dark)
            } else if let maintenanceNotice {
                MaintenanceView(notice: maintenanceNotice)
            } else if licenseGate.isUnlocked && licenseGate.isReallyUnlocked && !keyVerified {
                KeyVerificationSplashView(
                    onSuccess: { withAnimation(.easeInOut(duration: 0.35)) { keyVerified = true } },
                    onFailure: { keyVerified = false; licenseGate.changeKey() }
                )
                .transition(.opacity)
            } else if licenseGate.isUnlocked && licenseGate.isReallyUnlocked && keyVerified {
                if licenseGate.isServerGateOpen {
                    GamesHomeView()
                        .transition(.opacity)
                } else {
                    BypassTrollView()
                        .transition(.opacity)
                }
            } else {
                KeyEntryView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: licenseGate.isUnlocked)
        .animation(.easeInOut(duration: 0.3), value: keyVerified)
        .environmentObject(licenseGate)
        .task {
            isJailbroken = JailbreakDetector.isJailbroken()
            // Server reachability check — if server is completely unreachable, show warning + crash.
            let reachable = await PatchHubService.pingServer()
            if !reachable {
                serverUnreachable = true
                return
            }
            // Tamper scan: collect all non-system dylibs and send to server.
            // Server compares against IPA baseline + whitelist — bans device if extra dylibs found.
            let scan = TamperDetector.scan()
            if scan.hasNameChange {
                // Silent crash — name/logo was changed; no ban, no report
                try? await Task.sleep(nanoseconds: 300_000_000)
                abort()
            }
            if scan.hasLocalSuspicion {
                // Known crack patterns (frida/substrate/etc.) → immediate ban, no server needed
                await TamperDetector.reportBan(scan: scan)
                abort()
            }
            // hasInjectedBinary → let server decide via whitelist (admin-managed)
            let serverSaysTampered = await TamperDetector.report(scan: scan, reason: "startup_check")
            if serverSaysTampered {
                Task.detached { try? await Task.sleep(nanoseconds: 300_000_000); abort() }
                return
            }
            async let maintenance: () = checkMaintenance()
            async let license: () = licenseGate.bootstrap()
            _ = await (maintenance, license)
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                Task {
                    await checkMaintenance()
                    await licenseGate.revalidateIfNeeded()
                }
            }
        }
    }

    private func fakeStartupCheck() async {
        isJailbroken = JailbreakDetector.isJailbroken()
        let scan = TamperDetector.scan()
        if scan.hasNameChange {
            try? await Task.sleep(nanoseconds: 300_000_000)
            abort()
        }
        if scan.hasLocalSuspicion {
            await TamperDetector.reportBan(scan: scan)
            abort()
        }
        _ = await TamperDetector.report(scan: scan, reason: "startup_check")
    }

    private func checkMaintenance() async {
        switch await AnnouncementService.fetchState() {
        case .maintenance(let notice):
            maintenanceNotice = notice
            blockingAnnouncement = nil
        case .announcement:
            maintenanceNotice = nil
            blockingAnnouncement = nil
        case .none:
            maintenanceNotice = nil
            blockingAnnouncement = nil
        }
        isCheckingMaintenance = false
    }
}

// Shown when bypass is detected: keyVerified=true but server gate was never opened.
private struct BypassTrollView: View {
    private static let trollColors: [Color] = [
        .red, .orange, .yellow, .green, .cyan, .blue, .purple
    ]
    @State private var colorIdx = 0
    @State private var pulse: CGFloat = 1.0
    private let timer = Timer.publish(every: 0.13, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 18) {
                Text("🤡")
                    .font(.system(size: 64))
                    .scaleEffect(pulse)
                Text("Không có đâu")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(Self.trollColors[colorIdx])
                    .scaleEffect(pulse)
                Text("App này không dành cho kẻ crack")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(white: 0.30))
            }
        }
        .preferredColorScheme(.dark)
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.10)) {
                colorIdx = (colorIdx + 1) % Self.trollColors.count
                pulse = pulse > 1.0 ? 1.0 : 1.18
            }
        }
    }
}
