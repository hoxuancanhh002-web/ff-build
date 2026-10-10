import SwiftUI
import UIKit

// Chi ve vien top + 2 canh ben (khong co canh day)
private struct TabBarTopBorder: Shape {
    var radius: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        p.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                 radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        p.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                 radius: radius, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return p
    }
}


// Chi bo goc tren — thay the UnevenRoundedRectangle (iOS 17+) de tuong thich iOS 16
private struct TopRoundedShape: Shape {
    var radius: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        p.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                 radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        p.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                 radius: radius, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct GamesHomeView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var licenseGate: LicenseGateStore
    @StateObject private var store = PatchProjectStore()
    @StateObject private var ffESP = FreefireESPStore()
    @State private var games: [RemoteGameSummary] = []
    @State private var isLoadingGames = false
    @State private var showLanguagePicker = false
    @State private var announcement: Announcement?
    @State private var shownAnnouncementIDs: Set<String> = []
    @State private var selectedTab = 0
    @State private var ffTab = 0
    @State private var selectedGame: RemoteGameSummary? = nil
    @State private var contactURL: URL? = URL(string: "https://t.me/crackcyipa")
    @State private var showFakeAppSheet = false
    @State private var navigateToSettings = false
    @AppStorage("language.hasPicked") private var hasPickedLanguage = false
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue


    var body: some View {
        ZStack {
            homeStack

            if showLanguagePicker {
                languagePickerOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            if ffESP.isPatching {
                InjectProgressOverlay(store: ffESP)
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                    .zIndex(200)
            }

            if let toast = ffESP.toggleToast {
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        HStack(spacing: 10) {
                            Image(systemName: toast.isOn ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(toast.isOn
                                    ? Color(red: 0.20, green: 0.90, blue: 0.45)
                                    : Color(red: 1.0, green: 0.35, blue: 0.35))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(toast.isOn ? "Đã bật chức năng" : "Đã tắt chức năng")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color(white: 0.60))
                                Text(toast.featureName)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(red: 0.09, green: 0.11, blue: 0.16).opacity(0.97))
                                .shadow(color: .black.opacity(0.45), radius: 10, y: 4)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(
                                    toast.isOn
                                        ? Color(red: 0.20, green: 0.90, blue: 0.45).opacity(0.35)
                                        : Color(red: 1.0, green: 0.35, blue: 0.35).opacity(0.35),
                                    lineWidth: 1)
                        )
                        .padding(.trailing, 14)
                    }
                    .padding(.top, 72)
                    Spacer()
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(180)
            }

            if let msg = ffESP.autoInjectBlockReason {
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.orange)
                        Text(msg)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color(red: 0.12, green: 0.12, blue: 0.16).opacity(0.97))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.orange.opacity(0.4), lineWidth: 1))
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(150)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: showLanguagePicker)
        .animation(.easeInOut(duration: 0.2), value: ffESP.isPatching)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: ffESP.toggleToast?.id)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: ffESP.autoInjectBlockReason)
        .onReceive(NotificationCenter.default.publisher(for: .openMakeToolsFile)) { _ in
            selectedTab = 3
        }
        .task {
            if !hasPickedLanguage { showLanguagePicker = true }
        }
    }

    // MARK: - Home stack

    private var homeStack: some View {
        AnyNavigationStack {
            ZStack {
                AppTheme.cyberBase.ignoresSafeArea()
                Image("AppBg")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .opacity(0.18)
                    .allowsHitTesting(false)

                if selectedTab == 0 {
                    VStack(spacing: 0) {
                        innovaHeader
                        topTabBar
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 0, pinnedViews: []) {
                                        FreefireESPHomeSection(store: ffESP, tab: ffTab)
                                    .transition(.opacity)
                                Spacer(minLength: 20)
                            }
                            .animation(.spring(response: 0.34, dampingFraction: 0.82), value: ffTab)
                        }
                        .safeAreaInset(edge: .bottom) {
                            if !ffESP.isQuickPatching {
                                floatingInjectBar
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                        .animation(.easeInOut(duration: 0.25), value: ffESP.isQuickPatching)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .refreshable { await checkAnnouncement() }
            .task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                await checkAnnouncement()
            }
            .task { if let fetched = await PatchHubService.fetchContactURL() { contactURL = fetched } }
            .navigationDestination15(isPresented: Binding(
                get: { selectedGame != nil },
                set: { if !$0 { selectedGame = nil } }
            )) {
                if let game = selectedGame { GamePatchesView(game: game, store: store) }
            }
            .navigationDestination15(isPresented: $navigateToSettings) { SettingsView() }
            .toast($licenseGate.activationToast)
            .sheet(item: $draftCoordinator.request) { request in
                PatchProjectEditorView(
                    existingProject: nil,
                    passwordIsProtected: false,
                    initialDraft: request.draft
                ) { project, password in
                    store.create(project: project, password: password)
                    draftCoordinator.clear()
                }
            }
        }
        .tint(AppTheme.neonRed)
        .preferredColorScheme(.dark)
    }

    // MARK: - Innova header

    private var innovaHeader: some View {
        HStack(spacing: 10) {
            // Left: scope icon + title
            HStack(spacing: 10) {
                AppLogo(size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("CheatiOS")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(.white)
                        Text("Vip")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(AppTheme.neonRed)
                    }
                    HStack(spacing: 5) {
                        Text("✦ VIP PRO")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(AppTheme.neonRed.opacity(0.85), in: Capsule())
                        Text("INTERNAL ENGINE • BYPASS")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(Color(white: 0.38))
                    }
                }
            }

            Spacer()

            // Right: server badge + ready badge + gear
            HStack(spacing: 6) {
                HStack(spacing: 3) {
                    Circle().fill(Color(red: 0.10, green: 0.85, blue: 0.45)).frame(width: 5, height: 5)
                    Text("SV-C2")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 7).padding(.vertical, 4)
                .background(Color.white.opacity(0.07), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))

                HStack(spacing: 3) {
                    Circle().fill(Color(red: 0.10, green: 0.85, blue: 0.45)).frame(width: 5, height: 5)
                    Text("READY")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color(red: 0.10, green: 0.85, blue: 0.45))
                }
                .padding(.horizontal, 7).padding(.vertical, 4)
                .background(Color(red: 0.10, green: 0.85, blue: 0.45).opacity(0.10), in: Capsule())
                .overlay(Capsule().strokeBorder(Color(red: 0.10, green: 0.85, blue: 0.45).opacity(0.35), lineWidth: 1))

                Button { navigateToSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color(white: 0.50))
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.07), in: Circle())
                }
                .buttonStyle(.plain)
                .onLongPressGesture(minimumDuration: 3.0) { showFakeAppSheet = true }
                .sheet(isPresented: $showFakeAppSheet) { FakeAppSheetView() }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color(red: 0.05, green: 0.05, blue: 0.07))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.07)).frame(height: 0.5)
        }
    }

    // MARK: - Top Tab Bar

    private var topTabBar: some View {
        HStack(spacing: 4) {
            innovaTabItem(icon: "house.fill", label: "MAIN", index: 0)
            innovaTabItem(icon: "scope", label: "ESP/AIM", index: 1)
            innovaTabItem(icon: "slider.horizontal.3", label: "MISC", index: 2)
        }
        .padding(4)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color(red: 0.05, green: 0.05, blue: 0.07))
    }

    private func innovaTabItem(icon: String, label: String, index: Int) -> some View {
        let active = ffTab == index
        return Button {
            let gen = UIImpactFeedbackGenerator(style: .light)
            gen.impactOccurred()
            withAnimation(.easeInOut(duration: 0.18)) { ffTab = index; selectedTab = 0 }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: active ? .bold : .medium))
                Text(label)
                    .font(.system(size: 12, weight: active ? .bold : .medium))
            }
            .foregroundStyle(active ? .white : Color(white: 0.38))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(active ? AppTheme.neonRed : Color.clear, in: RoundedRectangle(cornerRadius: 9))
            .animation(.easeInOut(duration: 0.15), value: active)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Floating inject bar

    private var floatingInjectBar: some View {
        let patchInstalled = ffESP.selectedVariant == .freefire ? ffESP.isPatchInstalled : ffESP.isPatchInstalledMAX
        let variantLabel = ffESP.selectedVariant == .freefire ? "FREE FIRE THƯỜNG" : "FREE FIRE MAX"
        let detected = ffESP.selectedVariant == .freefire ? ffESP.detectedBundleID : ffESP.detectedMAXBundleID
        let accentColor: Color = patchInstalled ? AppTheme.neonRed : AppTheme.injectGreen

        return HStack(spacing: 10) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                if patchInstalled { ffESP.removePatches() } else { ffESP.patchGame() }
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.18)).frame(width: 34, height: 34)
                        if ffESP.isPatching {
                            ProgressView().scaleEffect(0.75).tint(.white)
                        } else {
                            Image(systemName: patchInstalled ? "arrow.uturn.backward.circle.fill" : "bolt.fill")
                                .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                        }
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(ffESP.isPatching ? "ĐANG XỬ LÝ..." : (patchInstalled ? "UN-PATCH" : "INJECT (\(variantLabel))"))
                            .font(.system(size: 12, weight: .heavy)).foregroundStyle(.white).kerning15(0.3)
                        Text(ffESP.isPatching ? "Vui lòng chờ..." : (patchInstalled ? "Gỡ bỏ patch đã cài" : "Bắt đầu kích hoạt chức năng"))
                            .font(.system(size: 10)).foregroundStyle(.white.opacity(0.65))
                    }
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(
                    patchInstalled
                        ? LinearGradient(colors: [Color(red: 0.55, green: 0.10, blue: 0.10), Color(red: 0.38, green: 0.07, blue: 0.07)], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [AppTheme.injectGreen, Color(red: 0.04, green: 0.55, blue: 0.28)], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(accentColor.opacity(0.45), lineWidth: 1.2))
                .shadow(color: accentColor.opacity(0.35), radius: 12, y: 3)
            }
            .buttonStyle(PressScaleButtonStyle())
            .disabled(ffESP.isPatching || detected == nil)
            .opacity(detected == nil && !ffESP.isPatching ? 0.45 : 1.0)

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                if !ffESP.isPatching {
                    if patchInstalled { ffESP.removePatches() } else { ffESP.patchGame() }
                }
            } label: {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(
                        patchInstalled
                            ? LinearGradient(colors: [Color(red: 0.55, green: 0.10, blue: 0.10), Color(red: 0.38, green: 0.07, blue: 0.07)], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [AppTheme.injectGreen, Color(red: 0.04, green: 0.55, blue: 0.28)], startPoint: .top, endPoint: .bottom)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: accentColor.opacity(0.35), radius: 10, y: 3)
            }
            .buttonStyle(PressScaleButtonStyle())
            .disabled(ffESP.isPatching)
        }
        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 12)
    }

    // MARK: - Device info card

    private var deviceInfoCard: some View {
        VStack(spacing: 0) {
            innoSectionHeader(title: "THÔNG TIN THIẾT BỊ", subtitle: "Phiên bản iOS & trạng thái hỗ trợ")
                .padding(.bottom, 4)

            deviceInfoRow(
                icon: "apple.logo",
                iconColor: Color(red: 0.10, green: 0.85, blue: 0.50),
                label: language.text("settings.ios_version"),
                value: shortOSVersion,
                valueColor: Color(red: 0.10, green: 0.85, blue: 0.50)
            )
            infoRowDivider
            deviceInfoRow(
                icon: "iphone",
                iconColor: Color(white: 0.60),
                label: language.text("common.device"),
                value: AppInfo.hardwareDisplayName,
                valueColor: .white
            )
            infoRowDivider
            deviceInfoRow(
                icon: appState.isSupported ? "checkmark.seal.fill" : "xmark.seal.fill",
                iconColor: appState.isSupported ? Color(red: 0.10, green: 0.85, blue: 0.50) : AppTheme.neonRed,
                label: language.text("settings.support"),
                value: language.text(appState.isSupported ? "settings.supported" : "settings.unsupported"),
                valueColor: appState.isSupported ? Color(red: 0.10, green: 0.90, blue: 0.52) : AppTheme.neonRed,
                glowColor: appState.isSupported ? Color(red: 0.10, green: 0.85, blue: 0.50).opacity(0.55) : AppTheme.neonRed.opacity(0.55)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AppTheme.techCardFill)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
    }

    private var infoRowDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 0.5)
            .padding(.vertical, 8)
    }

    private func deviceInfoRow(
        icon: String,
        iconColor: Color,
        label: String,
        value: String,
        valueColor: Color = .white,
        glowColor: Color = .clear
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.14))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color(white: 0.45))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(valueColor)
                .shadow(color: glowColor, radius: 5)
        }
    }

    // Innova-style section header
    private func innoSectionHeader(title: String, subtitle: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.white)
                    .kerning15(0.6)
                Text(subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color(white: 0.38))
            }
            Spacer()
            Rectangle()
                .fill(AppTheme.neonRed)
                .frame(width: 3, height: 32)
                .clipShape(Capsule())
        }
    }

    private var shortOSVersion: String {
        let v = AppInfo.osVersion
        return v.hasSuffix(".0") ? String(v.dropLast(2)) : v
    }

    // MARK: - Game section header

    private var gameSectionHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.techGlow, AppTheme.neonPurple],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: AppTheme.techGlow.opacity(0.6), radius: 6)
                Text("DANH S\u{00C1}CH GAME")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .kerning15(0.4)
                Spacer()
                HStack(spacing: 3) {
                    Text("Xem t\u{1EA5}t c\u{1EA3} (\(games.count))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.neonPurple.opacity(0.90))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.neonPurple.opacity(0.90))
                }
            }
            .padding(.horizontal, 20)

            // Decorative neon accent line
            LinearGradient(
                colors: [
                    AppTheme.neonPurple,
                    AppTheme.techGlow,
                    AppTheme.techGlow.opacity(0.08),
                    .clear
                ],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 2)
            .clipShape(Capsule())
            .padding(.horizontal, 20)
        }
    }

    private var gameGrid: some View {
        VStack(spacing: 10) {
            let featured = Array(games.prefix(2))
            let rest = Array(games.dropFirst(2))
            let pairs: [[RemoteGameSummary]] = stride(from: 0, to: rest.count, by: 2)
                .map { Array(rest[$0..<min($0+2, rest.count)]) }

            if !featured.isEmpty {
                HStack(spacing: 10) {
                    ForEach(Array(featured.enumerated()), id: \.element.id) { idx, game in
                        Button { selectedGame = game } label: {
                            GameCardView(
                                title: game.name,
                                subtitle: game.bundleID,
                                bannerColor: AppTheme.resolvedBannerColor(game.bannerColor),
                                iconURL: game.iconURL,
                                systemIconName: "app.fill",
                                actionLabel: game.type == "app" ? "M\u{1EDE} \u{1EE8}NG D\u{1EE4}NG" : "M\u{1EDE} GAME",
                                isFeatured: true
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    if featured.count == 1 { Spacer().frame(maxWidth: .infinity) }
                }
            }

            ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                HStack(spacing: 10) {
                    ForEach(pair) { game in
                        Button { selectedGame = game } label: {
                            GameCardView(
                                title: game.name,
                                subtitle: game.bundleID,
                                bannerColor: AppTheme.resolvedBannerColor(game.bannerColor),
                                iconURL: game.iconURL,
                                systemIconName: "app.fill",
                                actionLabel: game.type == "app" ? "M\u{1EDE} \u{1EE8}NG D\u{1EE4}NG" : "M\u{1EDE} GAME",
                                isFeatured: false
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    if pair.count == 1 { Spacer().frame(maxWidth: .infinity) }
                }
            }
        }
    }


    private var emptyGamesView: some View {
        VStack(spacing: 14) {
            if let ann = announcement {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(AppTheme.techGlow.opacity(0.7))

                if !ann.title.isEmpty {
                    Text(ann.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                if !ann.message.isEmpty {
                    Text(ann.message)
                        .font(.subheadline)
                        .foregroundStyle(Color(red: 0.45, green: 0.58, blue: 0.80))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                VStack(spacing: 10) {
                    if !ann.linkLabel.isEmpty, !ann.linkURL.isEmpty, let url = URL(string: ann.linkURL) {
                        Link(destination: url) {
                            Text(ann.linkLabel)
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color.cyan, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .foregroundStyle(.black)
                        }
                    }
                    if !ann.link2Label.isEmpty, !ann.link2URL.isEmpty, let url2 = URL(string: ann.link2URL) {
                        Link(destination: url2) {
                            Text(ann.link2Label)
                                .font(.body.weight(.medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 4)
            } else {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(AppTheme.techGlow.opacity(0.6))

                Text("App \u{0111}ang ti\u{1EBF}n h\u{00E0}nh n\u{00E2}ng c\u{1EA5}p m\u{1EDB}i, truy c\u{1EAD}p ngay Telegram \u{0111}\u{1EC3} nh\u{1EAD}n th\u{00F4}ng b\u{00E1}o m\u{1EDB}i")
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.45, green: 0.58, blue: 0.80))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button {
                    if let url = contactURL {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("V\u{00E0}o ngay")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.neonPurple, AppTheme.techGlow],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
                    .shadow(color: AppTheme.neonPurple.opacity(0.45), radius: 10, y: 3)
                }
            }
        }
    }

    // MARK: - Language picker overlay

    private var languagePickerOverlay: some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(AppTheme.techGlow.opacity(0.15))
                        .frame(width: 60, height: 60)
                        .blur(radius: 8)
                    Image(systemName: "globe")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.neonCyan, AppTheme.techGlow],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                Text("Ch\u{1ECD}n ng\u{00F4}n ng\u{1EEF} / Choose Language")
                    .font(.headline.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)

                VStack(spacing: 10) {
                    languageOptionButton(title: "Ti\u{1EBF}ng Vi\u{1EC7}t \u{1F1FB}\u{1F1F3}", code: .vietnamese)
                    languageOptionButton(title: "English \u{1F1FA}\u{1F1F8}", code: .english)
                }
            }
            .padding(26)
            .frame(maxWidth: 320)
            .techCard()
            .padding(.horizontal, 32)
        }
        .preferredColorScheme(.dark)
    }

    private func languageOptionButton(title: String, code: AppLanguage) -> some View {
        Button {
            languageCode = code.rawValue
            hasPickedLanguage = true
            showLanguagePicker = false
        } label: {
            Text(title)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .foregroundStyle(.white)
                .background(AppTheme.techCardFill, in: CutShape(cut: 13))
                .overlay(CutShape(cut: 13).strokeBorder(AppTheme.techCardStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data loading

    private func loadGames() async {
        isLoadingGames = true
        if let fetched = try? await PatchHubService.fetchGames() {
            games = fetched
        }
        isLoadingGames = false
    }

    private func checkAnnouncement() async {
        guard case .announcement(let fetched) = await AnnouncementService.fetchState(),
              !shownAnnouncementIDs.contains(fetched.id)
        else { return }
        shownAnnouncementIDs.insert(fetched.id)
        announcement = fetched
    }
}

// MARK: - GameCardView

struct GameCardView: View {
    let title: String
    let subtitle: String
    let bannerColor: Color
    let iconURL: URL?
    let systemIconName: String
    var actionLabel: String = "M\u{1EDE} GAME"
    var isFeatured: Bool = false

    private var cornerBadge: (text: String, color: Color)? {
        let n = title.lowercased()
        if n.contains("free fire") || n.contains("pubg") || n.contains("cod") || n.contains("battle") {
            return ("HOT", Color(red: 0.90, green: 0.12, blue: 0.20))
        }
        if actionLabel == "M\u{1EDE} \u{1EE8}NG D\u{1EE4}NG" {
            return ("PRO", Color(red: 0.32, green: 0.18, blue: 0.90))
        }
        return nil
    }

    private var iconSize: CGFloat { isFeatured ? 82 : 68 }
    private var cardHeight: CGFloat { isFeatured ? 172 : 138 }
    private var cornerRadius: CGFloat { 18 }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Full-bleed background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.02, blue: 0.16),
                    bannerColor.opacity(0.28),
                    Color(red: 0.03, green: 0.02, blue: 0.12)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            // Inner top highlight
            LinearGradient(
                colors: [.white.opacity(0.06), .clear],
                startPoint: .top, endPoint: .center
            )

            // Atmospheric glow behind icon
            RadialGradient(
                colors: [bannerColor.opacity(0.40), bannerColor.opacity(0.10), .clear],
                center: .center, startRadius: 0, endRadius: 80
            )
            .padding(.bottom, cardHeight * 0.30)
            .padding(.top, 8)

            // Game icon — centered upper area
            iconView
                .frame(width: iconSize, height: iconSize)
                .clipShape(RoundedRectangle(cornerRadius: iconSize * 0.22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: iconSize * 0.22, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [bannerColor.opacity(0.95), bannerColor.opacity(0.40)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: bannerColor.opacity(0.95), radius: isFeatured ? 12 : 9)
                .shadow(color: bannerColor.opacity(0.50), radius: isFeatured ? 26 : 20, y: 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.bottom, cardHeight * 0.33)

            // Bottom info strip with divider + arrow
            VStack(spacing: 0) {
                Divider()
                    .overlay(bannerColor.opacity(0.28))

                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: isFeatured ? 13.5 : 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(red: 0.18, green: 0.92, blue: 0.48))
                                .frame(width: 5, height: 5)
                                .shadow(color: Color(red: 0.18, green: 0.92, blue: 0.48), radius: 4)
                            Text("\u{0110}\u{00E3} s\u{1EB5}n s\u{00E0}ng")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(Color(red: 0.18, green: 0.92, blue: 0.48))
                        }
                    }
                    Spacer()
                    // Arrow button
                    Image(systemName: "arrow.right")
                        .font(.system(size: isFeatured ? 11 : 10, weight: .bold))
                        .foregroundStyle(bannerColor)
                        .padding(6)
                        .background(bannerColor.opacity(0.18), in: Circle())
                        .overlay(Circle().strokeBorder(bannerColor.opacity(0.55), lineWidth: 1))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
            }
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.88)],
                    startPoint: .top, endPoint: .bottom
                )
            )

            // HOT / PRO badge — top right (pill shape)
            if let badge = cornerBadge {
                Text(badge.text)
                    .font(.system(size: 8.5, weight: .black))
                    .kerning15(0.8)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        LinearGradient(
                            colors: [badge.color, badge.color.opacity(0.80)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        in: Capsule()
                    )
                    .shadow(color: badge.color.opacity(0.70), radius: 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(10)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: cardHeight)
        .clipShape(CutShape(cut: cornerRadius))
        .overlay(
            CutShape(cut: cornerRadius)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            bannerColor.opacity(0.92),
                            bannerColor.opacity(0.22),
                            bannerColor.opacity(0.60),
                            bannerColor.opacity(0.10)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: bannerColor.opacity(0.45), radius: isFeatured ? 20 : 16, x: 0, y: isFeatured ? 8 : 6)
        .shadow(color: .black.opacity(0.55), radius: 6, x: 0, y: 4)
    }

    @ViewBuilder
    private var iconView: some View {
        if let iconURL {
            CachedAsyncImage(url: iconURL) {
                placeholderIcon
            }
        } else {
            placeholderIcon
        }
    }

    private var placeholderIcon: some View {
        ZStack {
            bannerColor.opacity(0.28)
            Image(systemName: systemIconName)
                .resizable()
                .scaledToFit()
                .padding(14)
                .foregroundStyle(.white)
        }
    }
}

// MARK: - CachedAsyncImage

struct CachedAsyncImage<Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let placeholder: () -> Placeholder
    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url else { return }
            if let cached = RemoteImageCache.cachedImage(for: url) {
                uiImage = cached
            }
            if let fresh = await RemoteImageCache.fetchAndCache(url) {
                uiImage = fresh
            }
        }
    }
}

// MARK: - Inject progress full-screen overlay

private struct InjectProgressOverlay: View {
    @ObservedObject var store: FreefireESPStore

    var body: some View {
        ZStack {
            AppTheme.cyberBase.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo
                HStack(spacing: 0) {
                    Text("CheatiOS")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(.white)
                    Text(" Vip")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(AppTheme.neonRed)
                }
                .padding(.bottom, 28)

                // Game name
                Text(store.selectedVariant.rawValue)
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.bottom, 8)

                // Status label
                Text(store.injectPhaseLabel.isEmpty ? "Đang inject..." : store.injectPhaseLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.injectGreen)
                    .padding(.bottom, 36)

                // Progress bar + percentage
                VStack(spacing: 10) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 6)
                            Capsule()
                                .fill(AppTheme.injectGreen)
                                .frame(width: max(6, geo.size.width * store.injectProgress), height: 6)
                                .animation(.linear(duration: 0.12), value: store.injectProgress)
                        }
                    }
                    .frame(height: 6)

                    HStack {
                        let isVPNError = store.injectPhaseLabel.contains("mạng")
                        Text(store.injectPhaseLabel.isEmpty ? "Đang xử lý..." : store.injectPhaseLabel)
                            .font(.system(size: isVPNError ? 13 : 11, weight: isVPNError ? .semibold : .regular))
                            .foregroundStyle(isVPNError ? AppTheme.neonRed : .white.opacity(0.50))
                        Spacer()
                        if !isVPNError {
                            Text("\(Int(store.injectProgress * 100))%")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white.opacity(0.60))
                        }
                    }
                }
                .padding(.horizontal, 36)
                .padding(.bottom, 52)

                Spacer()

                // Disabled button
                HStack(spacing: 10) {
                    ProgressView().tint(.white).scaleEffect(0.85)
                    Text("Đang inject...")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(AppTheme.injectGreen.opacity(0.45), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(AppTheme.injectGreen.opacity(0.35), lineWidth: 1)
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 52)
            }
        }
    }
}
