import SwiftUI

struct KeyEntryView: View {
    @EnvironmentObject private var licenseGate: LicenseGateStore
    @Environment(\.appLanguage) private var language
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    var isChangingKey: Bool = false
    var onKeyChanged: ((String, String) -> Void)? = nil

    @State private var code = ""
    @State private var isSubmitting = false
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            // Background fills all screen via ignoresSafeArea — no fixed frame to misalign
            AppTheme.cyberBase.ignoresSafeArea()
            Image("AppBg")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .opacity(0.18)
                .allowsHitTesting(false)

            // Content — fixed full-screen height so Spacers never collapse to 0 when keyboard shows
            VStack(spacing: 0) {
                Spacer(minLength: 20)

                // Logo + branding
                VStack(spacing: 14) {
                    AppLogo(size: 80)
                    VStack(spacing: 4) {
                        HStack(spacing: 5) {
                            Text("CheatiOSVip")
                                .font(.system(size: 24, weight: .black))
                                .foregroundStyle(.white)
                            Text("Premium")
                                .font(.system(size: 24, weight: .black))
                                .foregroundStyle(AppTheme.neonRed)
                        }
                        HStack(spacing: 5) {
                            Text("✦ VIP PRO")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(AppTheme.neonRed.opacity(0.85), in: Capsule())
                            Text("INTERNAL ENGINE • BYPASS")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color(white: 0.38))
                        }
                    }
                }
                .padding(.bottom, 36)

                // Input card
                VStack(spacing: 14) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.neonRed.opacity(0.15))
                                .overlay(Circle().strokeBorder(AppTheme.neonRed.opacity(0.35), lineWidth: 1))
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.neonRed)
                        }
                        .frame(width: 34, height: 34)

                        TextField(language.text("license.placeholder"), text: $code)
                            .font(.system(size: 16, design: .monospaced).weight(.semibold))
                            .foregroundStyle(.white)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .focused($isFocused)
                            .submitLabel(.go)
                            .onSubmit(submit)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                isFocused ? AppTheme.neonRed.opacity(0.55) : Color.white.opacity(0.10),
                                lineWidth: 1
                            )
                            .animation(.easeInOut(duration: 0.18), value: isFocused)
                    )

                    if let errorMessage = licenseGate.errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                            Text(errorMessage)
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(Color(red: 0.95, green: 0.35, blue: 0.35))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .background(AppTheme.techCardFill)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(AppTheme.neonRed.opacity(0.22), lineWidth: 1)
                )
                .padding(.horizontal, 24)

                // Activate button
                Button(action: submit) {
                    Group {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 14, weight: .bold))
                                Text(language.text("license.activate"))
                                    .font(.system(size: 15, weight: .bold))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .foregroundStyle(.white)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.neonRed, Color(red: 0.68, green: 0.04, blue: 0.08)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: AppTheme.neonRed.opacity(0.45), radius: 14, y: 4)
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .disabled(isSubmitting || code.trimmingCharacters(in: .whitespaces).isEmpty)

                // Donate button
                Button {
                    openURL(URL(string: "https://cheatiosvip.net")!)
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 13))
                        Text("Donate CheatiOSVip")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(AppTheme.neonRed)
                    .background(AppTheme.neonRed.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(AppTheme.neonRed.opacity(0.28), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)

                Spacer(minLength: 20)

                Text("Make By ©CheatiOSVip")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color(white: 0.28))
                    .padding(.bottom, 28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(.keyboard)
        .preferredColorScheme(.dark)
    }

    private func submit() {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSubmitting else { return }
        isSubmitting = true
        let oldMasked = licenseGate.maskedKeyCode
        Task {
            _ = await licenseGate.redeem(code: trimmed)
            await MainActor.run {
                isSubmitting = false
                if isChangingKey && licenseGate.errorMessage == nil {
                    let newMasked = licenseGate.maskedKeyCode
                    onKeyChanged?(oldMasked, newMasked)
                    dismiss()
                }
            }
        }
    }
}
