import SwiftUI

struct KeyVerificationSplashView: View {
    var onSuccess: () -> Void
    var onFailure: () -> Void

    @EnvironmentObject private var licenseGate: LicenseGateStore

    @State private var rotation: Double = 0
    @State private var statusText: String = "Đang xác thực key..."
    @State private var statusColor: Color = Color(white: 0.65)
    @State private var showCheckmark: Bool = false
    @State private var showError: Bool = false
    @State private var screenOpacity: Double = 1

    private let red   = AppTheme.neonRed
    private let rose  = Color(red: 0.85, green: 0.05, blue: 0.20)

    var body: some View {
        ZStack {
            AppTheme.cyberBase.ignoresSafeArea()
            Image("AppBg")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .opacity(0.18)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                // Logo
                VStack(spacing: 14) {
                    AppLogo(size: 72)
                    VStack(spacing: 4) {
                        HStack(spacing: 5) {
                            Text("CheatiOS")
                                .font(.system(size: 22, weight: .black))
                                .foregroundStyle(.white)
                            Text("Vip")
                                .font(.system(size: 22, weight: .black))
                                .foregroundStyle(red)
                        }
                        HStack(spacing: 5) {
                            Text("✦ VIP PRO")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(red.opacity(0.85), in: Capsule())
                            Text("INTERNAL ENGINE • BYPASS")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color(white: 0.38))
                        }
                    }
                }
                .padding(.bottom, 52)

                // Spinner / Checkmark / X
                ZStack {
                    if !showCheckmark && !showError {
                        Circle()
                            .stroke(rose.opacity(0.18), lineWidth: 4)
                            .frame(width: 56, height: 56)
                        Circle()
                            .trim(from: 0, to: 0.72)
                            .stroke(
                                LinearGradient(
                                    colors: [red, rose.opacity(0.30)],
                                    startPoint: .leading, endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 56, height: 56)
                            .rotationEffect(.degrees(rotation))
                            .shadow(color: red.opacity(0.55), radius: 6)
                    } else if showCheckmark {
                        ZStack {
                            Circle()
                                .fill(AppTheme.injectGreen.opacity(0.18))
                                .frame(width: 56, height: 56)
                            Image(systemName: "checkmark")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(AppTheme.injectGreen)
                        }
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        ZStack {
                            Circle()
                                .fill(red.opacity(0.15))
                                .frame(width: 56, height: 56)
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(red)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.65), value: showCheckmark)
                .animation(.spring(response: 0.35, dampingFraction: 0.65), value: showError)

                // Status text
                Text(statusText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(statusColor)
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)
                    .animation(.easeInOut(duration: 0.25), value: statusText)

                // Retry button (only on error)
                if showError {
                    Button(action: { Task { await runCheck() } }) {
                        Text("Thử lại")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24).padding(.vertical, 9)
                            .background(red.opacity(0.85), in: Capsule())
                    }
                    .padding(.top, 16)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer()

                // Key display at bottom
                if let key = licenseGate.storedKeyCode {
                    Text(maskKey(key))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color(white: 0.30))
                        .padding(.bottom, 32)
                }
            }
        }
        .opacity(screenOpacity)
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            Task { await runCheck() }
        }
    }

    private func runCheck() async {
        showError = false
        showCheckmark = false
        statusText = "Đang xác thực key & thiết bị..."
        statusColor = Color(white: 0.65)

        guard let key = licenseGate.storedKeyCode, !key.isEmpty else {
            onFailure(); return
        }
        let deviceId = DeviceIdentity.current

        // Chạy song song ping + tối thiểu 1.5s để user thấy spinner
        async let ping = PatchHubService.fetchKeyPing(licenseKey: key, deviceId: deviceId)
        async let minWait: () = Task.sleep(nanoseconds: 1_500_000_000)
        let ok = await ping
        _ = try? await minWait

        if ok {
            licenseGate.openServerGate()
            withAnimation { showCheckmark = true }
            statusText = "Xác thực thành công"
            statusColor = AppTheme.injectGreen
            try? await Task.sleep(nanoseconds: 900_000_000)
            withAnimation(.easeInOut(duration: 0.35)) { screenOpacity = 0 }
            try? await Task.sleep(nanoseconds: 380_000_000)
            onSuccess()
        } else {
            withAnimation { showError = true }
            statusText = "Không thể xác thực key\nKiểm tra kết nối hoặc key đã hết hạn"
            statusColor = red.opacity(0.85)
        }
    }

    private func maskKey(_ key: String) -> String {
        guard key.count > 8 else { return key }
        let prefix = String(key.prefix(4))
        let suffix = String(key.suffix(4))
        let stars = String(repeating: "•", count: min(key.count - 8, 12))
        return "\(prefix)\(stars)\(suffix)"
    }
}
