import SwiftUI
import Darwin
import UIKit
import SafariServices

struct FreefireESPHomeSection: View {
    @ObservedObject var store: FreefireESPStore
    @EnvironmentObject private var appState: AppState
    /// 0 = Home (status + patch), 1 = ESP/AIM, 2 = Misc (settings)
    var tab: Int = 0

    private var isWaitingForExploit: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 18
            && !appState.exploitStatus.isSuccess
            && appState.isSupported
    }

    @State private var statCPU: Int = 0
    @State private var statRAMPct: Int = 0
    @State private var statRAMUsedMB: Int = 0
    @State private var showDNSSheet = false
    @State private var isDNSLoading = false
    @State private var dnsToastMsg: String? = nil
    @State private var dnsWebURL: URL? = nil
    @State private var uiConfig: UIConfig? = nil
    @State private var showCheckSheet = false
    @State private var checkSheetIsOn = false
    @State private var checkDiagText: String = ""
    @State private var gameOpenPending = false
    @State private var wasPatching = false
    @State private var showPatchErrorSheet = false
    @State private var patchErrorMsg = ""
    @State private var showAntiBanInfoSheet = false
    @State private var showV2LogSheet = false

    var body: some View {
        VStack(spacing: 12) {
            if tab == 0 {
                statusCard
                dnsButton
                checkButton
                antiBanCard
                antiBanV2Card
            } else if tab == 1 {
                innoSectionHeader(title: "ESP PROTOCOL", subtitle: "Tường nhìn xuyên & hiển thị đối thủ")
                    .padding(.horizontal, 4).padding(.top, 4)
                ServerTabView(store: store, sections: uiConfig?.esp ?? [])
            } else {
                innoSectionHeader(title: "MISC SETTINGS", subtitle: "Các cài đặt bổ sung khác")
                    .padding(.horizontal, 4).padding(.top, 4)
                ServerTabView(store: store, sections: uiConfig?.misc ?? [])
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .onAppear {
            let cached = PatchHubService.cachedUIConfig()
            if !cached.isEmpty { uiConfig = cached }
        }
        .task {
            while !Task.isCancelled {
                if let fresh = await PatchHubService.fetchUIConfig() {
                    uiConfig = fresh
                }
                try? await Task.sleep(nanoseconds: 60_000_000_000)
            }
        }
        .onChange(of: store.isPatching) { isNowPatching in
            if !isNowPatching && wasPatching {
                let errors = store.patchLog.filter { $0.level == .err }.count
                if errors == 0 && !store.patchLog.isEmpty {
                    gameOpenPending = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        guard gameOpenPending else { return }
                        gameOpenPending = false
                        openGame()
                    }
                }
            }
            wasPatching = isNowPatching
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            gameOpenPending = false
        }
        .onReceive(store.$patchResult) { result in
            guard let result = result else { return }
            if case .failure(let msg) = result {
                patchErrorMsg = msg
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showPatchErrorSheet = true
                }
            }
        }
        .sheet(isPresented: $showCheckSheet) {
            ESPResultSheet(isOn: checkSheetIsOn, diagText: checkDiagText, onDismiss: { showCheckSheet = false })
        }
        .sheet(isPresented: $showPatchErrorSheet) {
            PatchErrorSheet(message: patchErrorMsg, onDismiss: { showPatchErrorSheet = false })
        }
        .sheet(isPresented: Binding(
            get: { dnsWebURL != nil },
            set: { if !$0 { dnsWebURL = nil } }
        )) {
            if let url = dnsWebURL {
                SafariView(url: url)
            }
        }
    }

    // MARK: - Open game helper

    private func openGame() {
        let bundleID = store.selectedVariant == .freefire
            ? (store.detectedBundleID ?? "com.dts.freefireth")
            : (store.detectedMAXBundleID ?? "com.dts.freefiremax")
        // Private API (works on TrollStore / sideloaded)
        if let wsClass = NSClassFromString("LSApplicationWorkspace"),
           let ws = (wsClass as AnyObject).perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() {
            let sel = NSSelectorFromString("openApplicationWithBundleID:")
            if (ws as AnyObject).responds(to: sel) {
                _ = (ws as AnyObject).perform(sel, with: bundleID)
                return
            }
        }
        // URL scheme fallback
        for scheme in ["freefire://", "garena://"] {
            if let url = URL(string: scheme), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url); return
            }
        }
    }

    // MARK: - Status card

    private var statusCard: some View {
        VStack(spacing: 0) {
            // Section header
            innoSectionHeader(title: "TRẠNG THÁI HỆ THỐNG", subtitle: "Phát hiện game & tài nguyên thiết bị")
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

            // Game variant picker
            HStack(spacing: 4) {
                ForEach(FreefireESPStore.FFVariant.allCases) { variant in
                    let isSelected = store.selectedVariant == variant
                    Button { store.selectVariant(variant) } label: {
                        Text(variant.rawValue)
                            .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? .white : Color(white: 0.38))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(isSelected ? AppTheme.neonRed : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 8))
                            .animation(.easeInOut(duration: 0.12), value: isSelected)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 11))
            .padding(.horizontal, 16).padding(.bottom, 8)

            let detected = store.selectedVariant == .freefire ? store.detectedBundleID : store.detectedMAXBundleID
            let patchInstalled = store.selectedVariant == .freefire ? store.isPatchInstalled : store.isPatchInstalledMAX

            innoStatusRow(icon: "apps.iphone", label: store.selectedVariant.rawValue,
                value: detected != nil ? "Đã phát hiện" : "Không tìm thấy",
                valueColor: detected != nil ? Color(red: 0.10, green: 0.90, blue: 0.52) : AppTheme.neonRed,
                iconColor: detected != nil ? Color(red: 0.10, green: 0.85, blue: 0.50) : Color(white: 0.35))
            statusDivider
            innoStatusRow(icon: "doc.badge.gearshape", label: "Patch file",
                value: patchInstalled ? "Đã cài đặt" : "Chưa cài",
                valueColor: patchInstalled ? Color(red: 0.10, green: 0.90, blue: 0.52) : Color(red: 0.85, green: 0.65, blue: 0.10),
                iconColor: patchInstalled ? AppTheme.neonRed : Color(white: 0.35))
            statusDivider
            let cpuColor: Color = statCPU < 40 ? Color(red: 0.10, green: 0.90, blue: 0.52) : (statCPU < 70 ? Color(red: 1.00, green: 0.80, blue: 0.10) : AppTheme.neonRed)
            innoStatusRow(icon: "cpu", label: "CPU (app)", value: "\(statCPU)%", valueColor: cpuColor, iconColor: cpuColor)
            statusDivider
            let ramColor: Color = statRAMPct < 60 ? Color(red: 0.10, green: 0.90, blue: 0.52) : (statRAMPct < 80 ? Color(red: 1.00, green: 0.80, blue: 0.10) : AppTheme.neonRed)
            innoStatusRow(icon: "memorychip", label: "RAM (hệ thống)", value: "\(statRAMPct)%  \(statRAMUsedMB)MB", valueColor: ramColor, iconColor: ramColor)

            Spacer(minLength: 6)
        }
        .background(AppTheme.techCardFill)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
        .task {
            while !Task.isCancelled {
                updateSystemStats()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    private func innoStatusRow(icon: String, label: String, value: String, valueColor: Color, iconColor: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(iconColor.opacity(0.14)).frame(width: 36, height: 36)
                Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(iconColor)
            }
            Text(label).font(.system(size: 14, weight: .medium)).foregroundStyle(Color(white: 0.55))
            Spacer()
            Text(value).font(.system(size: 13, weight: .bold)).foregroundStyle(valueColor)
        }
        .padding(.horizontal, 16).padding(.vertical, 3)
    }

    private func innoSectionHeader(title: String, subtitle: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 12, weight: .heavy)).foregroundStyle(.white).kerning15(0.5)
                Text(subtitle).font(.system(size: 11)).foregroundStyle(Color(white: 0.35))
            }
            Spacer()
            Rectangle().fill(AppTheme.neonRed).frame(width: 3, height: 30).clipShape(Capsule())
        }
    }

    private func updateSystemStats() {
        // RAM system-wide via host_statistics64
        var vmInfo = vm_statistics64_data_t()
        var vmCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        withUnsafeMutablePointer(to: &vmInfo) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(vmCount)) {
                _ = host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &vmCount)
            }
        }
        let pgSize = UInt64(vm_page_size)
        let total = ProcessInfo.processInfo.physicalMemory
        let free = (UInt64(vmInfo.free_count) + UInt64(vmInfo.inactive_count)) * pgSize
        let used = total > free ? total - free : 0
        statRAMPct = total > 0 ? Int(used * 100 / total) : 0
        statRAMUsedMB = Int(used / 1_048_576)

        // CPU: sum across this app's threads
        var threads: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        guard task_threads(mach_task_self_, &threads, &threadCount) == KERN_SUCCESS,
              let threadList = threads else { return }
        defer {
            vm_deallocate(mach_task_self_,
                          vm_address_t(bitPattern: threadList),
                          vm_size_t(threadCount) * vm_size_t(MemoryLayout<thread_t>.size))
        }
        var totalCPU: Double = 0
        for i in 0..<Int(threadCount) {
            var info = thread_basic_info()
            var infoCount = mach_msg_type_number_t(MemoryLayout<thread_basic_info_data_t>.size / MemoryLayout<integer_t>.size)
            let kr = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(infoCount)) {
                    thread_info(threadList[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &infoCount)
                }
            }
            if kr == KERN_SUCCESS && (info.flags & TH_FLAGS_IDLE) == 0 {
                totalCPU += Double(info.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
            }
        }
        statCPU = min(Int(totalCPU), 999)
    }

    private var statusDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 0.5)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
    }

    // MARK: - Patch / INJECT button

    private var patchButton: some View {
        let detected = store.selectedVariant == .freefire ? store.detectedBundleID : store.detectedMAXBundleID
        let patchInstalled = store.selectedVariant == .freefire ? store.isPatchInstalled : store.isPatchInstalledMAX
        let variantLabel = store.selectedVariant == .freefire ? "FREE FIRE THƯỜNG" : "FREE FIRE MAX"

        return VStack(spacing: 10) {
            if patchInstalled && !store.isPatching {
                // Un-patch button
                Button { store.removePatches() } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(Color.white.opacity(0.15)).frame(width: 34, height: 34)
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("UN-PATCH")
                                .font(.system(size: 14, weight: .heavy)).foregroundStyle(.white).kerning15(0.5)
                            Text("Gỡ bỏ patch đã cài")
                                .font(.system(size: 11)).foregroundStyle(.white.opacity(0.65))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 18).padding(.vertical, 13)
                    .background(
                        LinearGradient(colors: [Color(red: 0.55, green: 0.10, blue: 0.10), Color(red: 0.38, green: 0.07, blue: 0.07)],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(AppTheme.neonRed.opacity(0.45), lineWidth: 1.2))
                }
                .buttonStyle(PressScaleButtonStyle())
            } else {
                // INJECT button (green, full width)
                let isBusy = store.isPatching || isWaitingForExploit
                Button { store.patchGame() } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(isBusy ? 0.10 : 0.18))
                                .frame(width: 38, height: 38)
                            if isBusy {
                                ProgressView().scaleEffect(0.85).tint(.white)
                            } else {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.isPatching ? "ĐANG INJECT..." : isWaitingForExploit ? "ĐANG CHUẨN BỊ..." : "INJECT (\(variantLabel))")
                                .font(.system(size: 13, weight: .heavy)).foregroundStyle(.white).kerning15(0.4)
                            Text(store.isPatching ? "Vui lòng chờ..." : isWaitingForExploit ? "Đang khởi động kernel (iOS 18)..." : "Bắt đầu kích hoạt chức năng")
                                .font(.system(size: 11)).foregroundStyle(.white.opacity(0.70))
                        }
                        Spacer()
                        if !isBusy {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(
                        isBusy
                            ? LinearGradient(colors: [Color(white: 0.12), Color(white: 0.10)], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [AppTheme.injectGreen, Color(red: 0.04, green: 0.55, blue: 0.28)], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(isBusy ? Color.white.opacity(0.08) : AppTheme.injectGreen.opacity(0.50), lineWidth: 1.2))
                    .shadow(color: isBusy ? .clear : AppTheme.injectGreen.opacity(0.40), radius: 16, y: 4)
                }
                .buttonStyle(PressScaleButtonStyle())
                .disabled(isBusy || detected == nil)
                .opacity((detected == nil && !isBusy) ? 0.40 : 1.0)
            }

            if detected == nil {
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        Circle().fill(Color(red: 1.0, green: 0.65, blue: 0.10).opacity(0.15)).frame(width: 36, height: 36)
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 15, weight: .bold)).foregroundStyle(Color(red: 1.0, green: 0.70, blue: 0.10))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Không tìm thấy \(store.selectedVariant.rawValue)")
                            .font(.system(size: 13, weight: .bold)).foregroundStyle(Color(red: 1.0, green: 0.80, blue: 0.35))
                        Text("Hãy cài game lên thiết bị trước khi sử dụng tính năng này.")
                            .font(.system(size: 11)).foregroundStyle(Color(white: 0.45))
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color(red: 1.0, green: 0.65, blue: 0.10).opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(red: 1.0, green: 0.70, blue: 0.10).opacity(0.25), lineWidth: 1))
            }
        }
    }

    // MARK: - DNS button

    private var dnsButton: some View {
        let blue = Color(red: 0.30, green: 0.70, blue: 1.00)
        return ZStack {
            Button {
                guard !isDNSLoading else { return }
                isDNSLoading = true
                Task {
                    do {
                        let result = try await PatchHubService.fetchDNSProfiles()
                        if let profile = result.profiles.first, let url = URL(string: profile.downloadURL) {
                            await MainActor.run {
                                dnsWebURL = url
                            }
                        } else {
                            showDNSToast("Không tải được danh sách DNS")
                        }
                    } catch {
                        showDNSToast("Lỗi kết nối — kiểm tra mạng")
                    }
                    isDNSLoading = false
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        // Shield outline frame
                        Image(systemName: "shield")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(blue)
                        // Download arrow inside shield
                        Image(systemName: "arrow.down")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(blue)
                            .offset(y: 1)
                    }
                    .frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("DOWNLOAD DNS")
                            .font(.system(size: 13, weight: .heavy)).foregroundStyle(.white).kerning15(0.4)
                        Text(isDNSLoading ? "Đang tải…" : "Mở trình duyệt trong app để cài")
                            .font(.system(size: 11)).foregroundStyle(Color(white: 0.45))
                    }
                    Spacer()
                    if isDNSLoading {
                        ProgressView().scaleEffect(0.75).tint(blue)
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 18, weight: .semibold)).foregroundStyle(blue.opacity(0.80))
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 13)
                .background(AppTheme.techCardFill)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(blue.opacity(0.40), lineWidth: 1.2))
            }
            .buttonStyle(PressScaleButtonStyle())
            .disabled(isDNSLoading)

            // Toast overlay
            if let msg = dnsToastMsg {
                VStack {
                    Spacer()
                    Text(msg)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Color(red: 0.08, green: 0.12, blue: 0.20).opacity(0.95))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(blue.opacity(0.35), lineWidth: 1))
                        .padding(.bottom, 8)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.spring(response: 0.3), value: dnsToastMsg != nil)
            }
        }
    }

    private func showDNSToast(_ msg: String) {
        withAnimation { dnsToastMsg = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation { dnsToastMsg = nil }
        }
    }

    // MARK: - AntiBan Memory V2 Card

    private var antiBanV2Card: some View {
        let orange = Color(red: 1.00, green: 0.55, blue: 0.10)
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(orange.opacity(0.15)).frame(width: 36, height: 36)
                Image(systemName: "shield.slash")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(store.antiBanV2Enabled ? orange : orange.opacity(0.6))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("ANTIBAN MEMORY V2")
                    .font(.system(size: 13, weight: .heavy)).foregroundStyle(.white)
                Text("Bảo vệ nâng cao liên tục")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(white: 0.45))
            }
            Spacer()
            if store.antiBanV2Enabled {
                Button { showV2LogSheet = true } label: {
                    Text("Xem log")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color(red: 0.20, green: 0.20, blue: 0.26))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(orange.opacity(0.40), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            Button {
                if store.antiBanV2Enabled { store.disableAntiBanV2() } else { store.enableAntiBanV2() }
            } label: {
                Text(store.antiBanV2Enabled ? "Tắt Anti" : "Bật Anti")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(store.antiBanV2Enabled
                        ? Color(red: 0.88, green: 0.22, blue: 0.22)
                        : Color(red: 0.10, green: 0.76, blue: 0.32))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .background(AppTheme.techCardFill)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(store.antiBanV2Enabled ? orange.opacity(0.45) : Color.white.opacity(0.07), lineWidth: 1.2))
        .animation(.easeInOut(duration: 0.2), value: store.antiBanV2Enabled)
        .sheet(isPresented: $showV2LogSheet) {
            AntiBanV2LogSheet(store: store)
        }
    }

    // MARK: - SpinBot 360° Card

    private var spinBotCard: some View {
        let cyan = Color(red: 0.10, green: 0.80, blue: 1.00)
        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(cyan.opacity(0.15)).frame(width: 36, height: 36)
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(store.spinBotEnabled ? cyan : cyan.opacity(0.5))
                        .rotationEffect(.degrees(store.spinBotEnabled ? 360 : 0))
                        .animation(store.spinBotEnabled
                            ? .linear(duration: 1.2).repeatForever(autoreverses: false)
                            : .default,
                            value: store.spinBotEnabled)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("SPIN BOT 360°")
                        .font(.system(size: 13, weight: .heavy)).foregroundStyle(.white)
                    Text(store.spinBotEnabled
                        ? "Đang xoay · \(store.spinBotSpeedIndex * 12)°/s"
                        : "Xoay nhân vật 360° liên tục")
                        .font(.system(size: 11))
                        .foregroundStyle(store.spinBotEnabled ? cyan.opacity(0.85) : Color(white: 0.45))
                }
                Spacer()
                Button {
                    store.spinBotEnabled.toggle()
                    store.flushStatePublic()
                } label: {
                    Text(store.spinBotEnabled ? "Tắt Spin" : "Bật Spin")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(store.spinBotEnabled
                            ? Color(red: 0.88, green: 0.22, blue: 0.22)
                            : Color(red: 0.08, green: 0.65, blue: 0.90))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.vertical, 13)

            if store.spinBotEnabled {
                Rectangle().fill(Color.white.opacity(0.06)).frame(height: 0.5).padding(.horizontal, 16)
                VStack(spacing: 8) {
                    HStack {
                        Text("Tốc độ xoay spin")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(white: 0.50))
                        Spacer()
                        Text("\(store.spinBotSpeedIndex * 12)°/s")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(cyan)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(store.spinBotSpeedIndex) },
                            set: { store.spinBotSpeedIndex = Int($0.rounded()); store.flushStatePublic() }
                        ),
                        in: 0...300,
                        step: 1
                    )
                    .accentColor(cyan)
                    HStack {
                        Text("Nhẹ").font(.system(size: 10)).foregroundStyle(Color(white: 0.30))
                        Spacer()
                        Text("Tối đa").font(.system(size: 10)).foregroundStyle(Color(white: 0.30))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.18))
            }
        }
        .background(AppTheme.techCardFill)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(store.spinBotEnabled ? cyan.opacity(0.45) : Color.white.opacity(0.07), lineWidth: 1.2))
        .animation(.easeInOut(duration: 0.2), value: store.spinBotEnabled)
    }

    // MARK: - AntiBan Memory Card

    private var antiBanCard: some View {
        let purple = Color(red: 0.62, green: 0.32, blue: 1.00)
        return VStack(spacing: 0) {
            // Header + Toggle
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(purple.opacity(0.16)).frame(width: 36, height: 36)
                    Image(systemName: "shield.slash.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(store.antiBanRunning ? purple : purple.opacity(0.75))
                        .scaleEffect(store.antiBanRunning ? 1.10 : 1.0)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                                   value: store.antiBanRunning)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("ANTIBAN MEMORY")
                        .font(.system(size: 13, weight: .heavy)).foregroundStyle(.white)
                    Text("Bật/tắt nút trong game")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(white: 0.45))
                }
                Spacer()
                Button {
                    if store.antiBanBtnVisible { store.hideInGameBtn() } else { store.showInGameBtn() }
                } label: {
                    Text(store.antiBanBtnVisible ? "Ẩn nút" : "Hiện nút")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(store.antiBanBtnVisible
                            ? Color(red: 0.88, green: 0.22, blue: 0.22)
                            : Color(red: 0.10, green: 0.76, blue: 0.32))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                Button {
                    showAntiBanInfoSheet = true
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 1.5)
                            .frame(width: 28, height: 28)
                        Text("i")
                            .font(.system(size: 13, weight: .semibold, design: .serif))
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.vertical, 13)

            // Progress panel (shown during enable/disable operation)
            if !store.antiBanStatusMsg.isEmpty {
                Rectangle().fill(Color.white.opacity(0.06)).frame(height: 0.5).padding(.horizontal, 16)
                VStack(spacing: 8) {
                    ProgressView(value: store.antiBanProgress, total: 1.0)
                        .tint(purple)
                        .animation(.linear(duration: 0.08), value: store.antiBanProgress)
                        .padding(.horizontal, 16)
                    Text(store.antiBanStatusMsg)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(purple)
                }
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.18))
            }
        }
        .background(AppTheme.techCardFill)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(store.antiBanEnabled ? purple.opacity(0.45) : Color.white.opacity(0.07), lineWidth: 1.2))
        .animation(.easeInOut(duration: 0.2), value: store.antiBanEnabled)
        .animation(.easeInOut(duration: 0.15), value: store.antiBanRunning)
        .animation(.easeInOut(duration: 0.15), value: store.antiBanLog.count)
        .sheet(isPresented: $showAntiBanInfoSheet) {
            if #available(iOS 16, *) {
                AntiBanBackupSheet(store: store)
                    .presentationDetents([.height(400), .large])
                    .presentationDragIndicator(.visible)
            } else {
                AntiBanBackupSheet(store: store)
            }
        }
    }

    private var checkButton: some View {
        let green = Color(red: 0.10, green: 0.88, blue: 0.52)
        let patchInstalled = store.selectedVariant == .freefire ? store.isPatchInstalled : store.isPatchInstalledMAX
        return Button {
            checkSheetIsOn = patchInstalled
            checkDiagText = store.checkESPStatus()
            showCheckSheet = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(green.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(green)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("KIỂM TRA CHỨC NĂNG")
                        .font(.system(size: 13, weight: .heavy)).foregroundStyle(.white)
                    Text("Xem chức năng có đang hoạt động không")
                        .font(.system(size: 11)).foregroundStyle(Color(white: 0.45))
                }
                Spacer()
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 18, weight: .semibold)).foregroundStyle(green.opacity(0.75))
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
            .background(AppTheme.techCardFill)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(green.opacity(0.35), lineWidth: 1.2))
        }
        .buttonStyle(.plain)
    }

}

// MARK: - AntiBan Backup Sheet

private struct AntiBanBackupSheet: View {
    @ObservedObject var store: FreefireESPStore
    @State private var isRestoring = false
    @State private var done = false
    @State private var showGuide = false

    private let purple = Color(red: 0.62, green: 0.32, blue: 1.00)

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    ZStack {
                        Circle().fill(purple.opacity(0.18)).frame(width: 44, height: 44)
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(purple)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Bảo vệ tài khoản")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(.white)
                        Text("Tối ưu hóa an toàn cho phiên chơi")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(white: 0.5))
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 16)

                Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1).padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 10) {
                    Label("Chức năng này giúp tăng cường lớp bảo vệ tài khoản trong suốt phiên chơi game.", systemImage: "lock.shield")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(white: 0.55))
                    Label("Nhấn nút bên dưới để đồng bộ lại trạng thái bảo vệ về mặc định khi cần thiết.", systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(white: 0.55))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Spacer()

                // Backup button
                Button {
                    guard !isRestoring else { return }
                    isRestoring = true
                    done = false
                    Task { @MainActor in
                        store.restoreAntiBanFiles()
                        try? await Task.sleep(nanoseconds: 800_000_000)
                        isRestoring = false
                        done = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isRestoring {
                            ProgressView().tint(.white).scaleEffect(0.85)
                        } else {
                            Image(systemName: done ? "checkmark.circle.fill" : "arrow.counterclockwise")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        Text(isRestoring ? "Đang xử lý..." : done ? "Đã hoàn tất!" : "Đồng bộ & Tối ưu bảo vệ")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(done ? Color(red: 0.10, green: 0.72, blue: 0.35) : purple)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .disabled(isRestoring)

                // Guide link
                NavigationLink(destination: AntiBanGuideView()) {
                    HStack(spacing: 6) {
                        Image(systemName: "book.pages")
                            .font(.system(size: 13))
                        Text("Xem hướng dẫn antiban v1")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(white: 0.35))
                    }
                    .foregroundStyle(purple)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }
                .padding(.bottom, 16)
            }
            .background(Color(red: 0.09, green: 0.09, blue: 0.12))
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - AntiBan Guide

private struct AntiBanGuideView: View {
    private let purple = Color(red: 0.62, green: 0.32, blue: 1.00)

    private struct Step: Identifiable {
        let id: Int
        let icon: String
        let title: String
        let desc: String
    }

    private let steps: [Step] = [
        Step(id: 1, icon: "bolt.fill",           title: "Kích hoạt tính năng",
             desc: "Mở app, nhấn INJECT để kích hoạt. Sau đó mở Free Fire và vào sảnh chờ."),
        Step(id: 2, icon: "shield.fill",          title: "Bật bảo vệ trong game",
             desc: "Trong game sẽ có nút ANTIBAN ở góc màn hình. Nhấn vào để bật — hệ thống bảo vệ sẽ tự động kích hoạt và duy trì trong suốt phiên chơi."),
        Step(id: 3, icon: "checkmark.seal.fill",  title: "Chơi bình thường",
             desc: "Sau khi bật, chơi game như thường. App chạy nền để duy trì kết nối và bảo vệ tài khoản liên tục."),
        Step(id: 4, icon: "arrow.triangle.2.circlepath", title: "Đồng bộ lại khi cần",
             desc: "Khi cần đặt lại trạng thái bảo vệ (ví dụ trước khi cập nhật game), nhấn nút Đồng bộ & Tối ưu bảo vệ ở màn hình trước, hoặc tắt từ nút trong game."),
        Step(id: 5, icon: "exclamationmark.triangle.fill", title: "Lưu ý quan trọng",
             desc: "Không tắt app trong khi đang chơi — app cần chạy nền để duy trì kết nối bảo vệ. Nếu app bị tắt, tính năng sẽ ngừng hoạt động cho đến khi inject lại."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Hướng dẫn sử dụng\nAntiban Memory v1")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 20)

                ForEach(steps) { step in
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            Circle().fill(purple.opacity(0.18)).frame(width: 38, height: 38)
                            Image(systemName: step.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(purple)
                        }
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 6) {
                                Text("Bước \(step.id)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(purple.opacity(0.8))
                                    .padding(.horizontal, 7).padding(.vertical, 2)
                                    .background(purple.opacity(0.12))
                                    .clipShape(Capsule())
                                Text(step.title)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            Text(step.desc)
                                .font(.system(size: 12))
                                .foregroundStyle(Color(white: 0.6))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)

                    if step.id < steps.count {
                        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1).padding(.horizontal, 20)
                    }
                }

                Spacer(minLength: 32)
            }
        }
        .background(Color(red: 0.09, green: 0.09, blue: 0.12))
        .navigationTitle("Hướng dẫn")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - AntiBan Log Row

private struct AntiBanLogRow: View {
    let entry: AntiBanLogEntry
    var body: some View {
        let col = entry.kind.iconColor
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: entry.kind.iconName)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(col)
                .frame(width: 14, alignment: .center)
                .padding(.top, 1)
            Text(entry.time)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color(white: 0.28))
                .frame(width: 52, alignment: .leading)
            Text(entry.message)
                .font(.system(size: 11))
                .foregroundStyle(col.opacity(0.90))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14).padding(.vertical, 3)
    }
}

// MARK: - In-App Safari Browser

private struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let cfg = SFSafariViewController.Configuration()
        cfg.entersReaderIfAvailable = false
        let vc = SFSafariViewController(url: url, configuration: cfg)
        vc.preferredControlTintColor = UIColor(red: 0.93, green: 0.12, blue: 0.16, alpha: 1)
        return vc
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

// MARK: - Patch Error Sheet

private struct PatchErrorSheet: View {
    let message: String
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss

    private let orange = Color(red: 1.00, green: 0.65, blue: 0.10)

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.07, blue: 0.13).ignoresSafeArea()
            Circle()
                .fill(RadialGradient(colors: [orange.opacity(0.18), .clear],
                                     center: .center, startRadius: 0, endRadius: 180))
                .frame(width: 360, height: 360).offset(y: -60).blur(radius: 20)

            VStack(spacing: 0) {
                Capsule().fill(Color.white.opacity(0.18)).frame(width: 36, height: 4)
                    .padding(.top, 12).padding(.bottom, 20)

                ZStack {
                    Circle().fill(orange.opacity(0.18)).frame(width: 80, height: 80)
                    Circle().strokeBorder(orange.opacity(0.40), lineWidth: 1.5).frame(width: 80, height: 80)
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 36, weight: .bold)).foregroundStyle(orange)
                }
                .padding(.bottom, 14)

                Text("Patch thất bại")
                    .font(.system(size: 20, weight: .heavy)).foregroundStyle(orange)
                    .padding(.bottom, 6)
                Text("Đã xảy ra lỗi khi ghi file vào game")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(red: 0.52, green: 0.63, blue: 0.82))
                    .padding(.bottom, 20)

                // Steps card
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("CÓ THỂ LÀM GÌ?")
                            .font(.system(size: 11, weight: .heavy)).foregroundStyle(orange.opacity(0.80)).kerning15(0.8)
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

                    stepRow(num: "1", icon: "arrow.uturn.backward.circle.fill",
                            color: Color(red: 1.0, green: 0.75, blue: 0.15),
                            title: "Thử bấm Patch lại",
                            desc: "Đóng bảng này và bấm 'Patch File vào Game' một lần nữa.")
                    divider
                    stepRow(num: "2", icon: "gamecontroller.fill",
                            color: Color(red: 0.55, green: 0.72, blue: 1.0),
                            title: "Mở Free Fire trước, rồi quay lại patch",
                            desc: "Đảm bảo game đã khởi động ít nhất một lần để hệ thống nhận dạng đúng đường dẫn.")
                    divider
                    stepRow(num: "3", icon: "trash.circle.fill",
                            color: Color(red: 0.80, green: 0.40, blue: 1.0),
                            title: "Xoá dữ liệu game rồi mở lại",
                            desc: "Vào Cài đặt → Cổng ứng dụng → Free Fire → Xoá dữ liệu app → mở lại game một lần rồi thử patch.")
                    if !message.isEmpty && !message.hasPrefix("Không tìm") {
                        divider
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 14)).foregroundStyle(Color(red: 0.52, green: 0.63, blue: 0.82))
                                .padding(.top, 1)
                            Text(message)
                                .font(.system(size: 12)).foregroundStyle(Color(red: 0.52, green: 0.63, blue: 0.82))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                    }
                }
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(orange.opacity(0.20), lineWidth: 1))
                .padding(.horizontal, 16).padding(.bottom, 24)

                Button { dismiss(); onDismiss() } label: {
                    Text("Đã hiểu")
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(LinearGradient(
                            colors: [Color(red: 0.50, green: 0.30, blue: 0.05), Color(red: 0.38, green: 0.22, blue: 0.03)],
                            startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(orange.opacity(0.45), lineWidth: 1.2))
                }
                .buttonStyle(.plain).padding(.horizontal, 16).padding(.bottom, 20)
            }
        }
        .presentationFractionDetent(0.72)
        .presentationDragIndicator15(false)
        .preferredColorScheme(.dark)
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.07)).frame(height: 0.5).padding(.leading, 58)
    }

    private func stepRow(num: String, icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.18)).frame(width: 38, height: 38)
                Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(num).font(.system(size: 10, weight: .heavy)).foregroundStyle(color)
                        .frame(width: 16, height: 16).background(color.opacity(0.20)).clipShape(Circle())
                    Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                }
                Text(desc).font(.system(size: 12)).foregroundStyle(Color(red: 0.52, green: 0.63, blue: 0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}

// MARK: - ESP Result Sheet

private struct ESPResultSheet: View {
    let isOn: Bool
    let diagText: String
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss

    private let green  = Color(red: 0.10, green: 0.92, blue: 0.55)
    private let red    = Color(red: 1.00, green: 0.38, blue: 0.38)
    private let accent: Color

    init(isOn: Bool, diagText: String = "", onDismiss: @escaping () -> Void) {
        self.isOn = isOn
        self.diagText = diagText
        self.onDismiss = onDismiss
        self.accent = isOn
            ? Color(red: 0.10, green: 0.92, blue: 0.55)
            : Color(red: 1.00, green: 0.38, blue: 0.38)
    }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.07, blue: 0.13).ignoresSafeArea()
            // glow
            Circle()
                .fill(RadialGradient(
                    colors: [accent.opacity(0.22), .clear],
                    center: .center, startRadius: 0, endRadius: 200))
                .frame(width: 400, height: 400)
                .offset(y: -60)
                .blur(radius: 20)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // handle
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 36, height: 4)
                        .padding(.top, 12)
                        .padding(.bottom, 20)

                    // icon
                    ZStack {
                        Circle().fill(accent.opacity(0.18)).frame(width: 88, height: 88)
                        Circle().strokeBorder(accent.opacity(0.40), lineWidth: 1.5).frame(width: 88, height: 88)
                        Image(systemName: isOn ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(accent)
                    }
                    .padding(.bottom, 16)

                    // title
                    Text(isOn ? "Chức năng đang hoạt động" : "Chức năng chưa hoạt động")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(isOn ? Color(red: 0.24, green: 0.88, blue: 0.52) : Color(red: 0.95, green: 0.28, blue: 0.35))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 6)

                    Text(isOn
                        ? "Hệ thống sẵn sàng — vào game và bắt đầu trận là dùng được ngay"
                        : "Patch chưa cài hoặc chưa bật chức năng nào trong app")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(red: 0.52, green: 0.63, blue: 0.82))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 12)

                    if !diagText.isEmpty {
                        Text(diagText)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color(white: 0.75))
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(white: 0.08).cornerRadius(10))
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    }

                    // steps card
                    VStack(alignment: .leading, spacing: 0) {
                        stepHeader(isOn ? "Những gì bạn có thể làm" : "Hướng dẫn kích hoạt lại")

                        if isOn {
                            stepRow(num: "1", icon: "gamecontroller.fill", color: green,
                                    title: "Vào Free Fire và chơi bình thường",
                                    desc: "Chức năng đã sẵn sàng — mở game và bắt đầu trận là dùng được ngay.")
                            divider
                            stepRow(num: "2", icon: "slider.horizontal.3", color: Color(red: 0.55, green: 0.72, blue: 1.0),
                                    title: "Bật / tắt chức năng bất kỳ lúc nào",
                                    desc: "Vuốt đa nhiệm vào app, bật hoặc tắt tính năng, rồi quay lại game là áp dụng ngay.")
                            divider
                            stepRow(num: "3", icon: "arrow.clockwise.circle.fill", color: Color(red: 0.80, green: 0.65, blue: 1.0),
                                    title: "Khi nào cần Inject lại?",
                                    desc: "Nếu game được cập nhật hoặc chức năng tự dưng không hoạt động thì bấm Inject lại là ổn.")
                        } else {
                            stepRow(num: "1", icon: "bolt.fill", color: Color(red: 1.0, green: 0.75, blue: 0.15),
                                    title: "Bấm Inject (Free Fire Thường / MAX)",
                                    desc: "Về màn hình MAIN → bấm nút Inject lớn bên dưới để cài patch vào game.")
                            divider
                            stepRow(num: "2", icon: "togglepower", color: Color(red: 0.55, green: 0.72, blue: 1.0),
                                    title: "Bật ít nhất 1 chức năng trong ESP/AIM hoặc MISC",
                                    desc: "Vào tab ESP/AIM hoặc MISC, bật tính năng bạn muốn dùng trước khi vào game.")
                            divider
                            stepRow(num: "3", icon: "gamecontroller.fill", color: Color(red: 0.80, green: 0.65, blue: 1.0),
                                    title: "Vào Free Fire và bắt đầu trận",
                                    desc: "Mở game, vào lobby và bắt đầu trận — chức năng sẽ tự áp dụng.")
                            divider
                            stepRow(num: "4", icon: "creditcard.fill", color: red,
                                    title: "Vẫn không hoạt động? Kiểm tra tài khoản",
                                    desc: "Có thể tài khoản đã hết hạn hoặc chưa kích hoạt trên thiết bị này. Xem thông tin key ở cuối màn hình chính.")
                        }
                    }
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(accent.opacity(0.20), lineWidth: 1))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)

                    // dismiss
                    Button {
                        dismiss(); onDismiss()
                    } label: {
                        Text(isOn ? "Vào game thôi!" : "Đã hiểu, làm theo hướng dẫn")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(
                                LinearGradient(
                                    colors: isOn
                                        ? [Color(red: 0.05, green: 0.52, blue: 0.28), Color(red: 0.03, green: 0.38, blue: 0.20)]
                                        : [Color(red: 0.52, green: 0.10, blue: 0.10), Color(red: 0.38, green: 0.07, blue: 0.07)],
                                    startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(accent.opacity(0.45), lineWidth: 1.2))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
        }
        .presentationFractionDetent(0.72)
        .presentationDragIndicator15(false)
        .preferredColorScheme(.dark)
    }

    private func stepHeader(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(accent.opacity(0.80))
                .kerning15(0.8)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 0.5)
            .padding(.leading, 58)
    }

    private func stepRow(num: String, icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.18))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(num)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(color)
                        .frame(width: 16, height: 16)
                        .background(color.opacity(0.20))
                        .clipShape(Circle())
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text(desc)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color(red: 0.52, green: 0.63, blue: 0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// MARK: - AntiBan V2 Log Sheet

private struct AntiBanV2LogSheet: View {
    @ObservedObject var store: FreefireESPStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.06, green: 0.06, blue: 0.09).ignoresSafeArea()
                if store.antiBanV2Logs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "shield.slash")
                            .font(.system(size: 36))
                            .foregroundStyle(Color(red: 1.00, green: 0.55, blue: 0.10).opacity(0.5))
                        Text("Chưa có log — đang chờ scan...")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(white: 0.45))
                    }
                } else {
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(store.antiBanV2Logs.enumerated()), id: \.offset) { _, entry in
                                Text(entry)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(entry.contains("Xóa") ? Color(red: 1.00, green: 0.45, blue: 0.20) : Color(white: 0.55))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 14).padding(.vertical, 3)
                                Divider().background(Color.white.opacity(0.05))
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .navigationTitle("AntiBan V2 — Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Xóa log") { store.antiBanV2Logs = [] }
                        .font(.system(size: 13))
                        .foregroundStyle(Color(red: 1.00, green: 0.55, blue: 0.10))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { dismiss() }
                        .font(.system(size: 13, weight: .semibold))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

