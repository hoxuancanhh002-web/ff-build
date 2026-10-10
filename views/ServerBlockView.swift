import SwiftUI

struct ServerBlockView: View {
    @State private var countdown = 5
    @State private var pulseScale: CGFloat = 1.0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            AppTheme.cyberBase.ignoresSafeArea()
            Image("AppBg")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .opacity(0.12)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                // Warning icon
                ZStack {
                    Circle()
                        .fill(AppTheme.neonRed.opacity(0.12))
                        .frame(width: 90, height: 90)
                        .scaleEffect(pulseScale)
                        .animation(
                            .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                            value: pulseScale
                        )
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(AppTheme.neonRed)
                }
                .padding(.bottom, 28)
                .onAppear { pulseScale = 1.12 }

                // Title
                Text("MẤT KẾT NỐI MÁY CHỦ")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.white)

                    .padding(.bottom, 12)

                // Description
                Text("Không thể kết nối đến server.\nVui lòng kiểm tra mạng và thử lại.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(white: 0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)

                // Countdown circle
                ZStack {
                    Circle()
                        .stroke(AppTheme.neonRed.opacity(0.18), lineWidth: 3)
                        .frame(width: 64, height: 64)
                    Circle()
                        .trim(from: 0, to: CGFloat(countdown) / 5.0)
                        .stroke(AppTheme.neonRed, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.4), value: countdown)
                    Text("\(countdown)")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(AppTheme.neonRed)
                }
                .padding(.bottom, 16)

                Text("App sẽ tự đóng sau \(countdown) giây")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(white: 0.38))

                Spacer()

                // Footer
                Text("CheatiOS Vip • Bảo mật hệ thống")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(white: 0.22))
                    .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(.dark)
        .onReceive(timer) { _ in
            if countdown > 1 {
                countdown -= 1
            } else {
                timer.upstream.connect().cancel()
                abort()
            }
        }
    }
}
