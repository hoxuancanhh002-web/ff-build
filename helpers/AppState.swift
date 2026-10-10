import Foundation

class AppState: ObservableObject {
    @Published var exploitStatus: ExploitStatus = .notStarted
    @Published var unsupportedMessage: String?
    private var exploitStarted = false

    var isSupported: Bool { unsupportedMessage == nil }

    /// Runs the kernel exploit chain once per session on a background thread.
    /// Safe to call multiple times — no-op if already started or device unsupported.
    func runExploit() {
        guard !exploitStarted, isSupported else { return }
        exploitStarted = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let ok = KernelExploit.run()
            DispatchQueue.main.async {
                self?.exploitStatus = ok
                    ? .success(method: "kexploit_opa334")
                    : .failed(method: "kexploit_opa334", code: -1)
            }
        }
    }

    func detectSupport() {
        let v = AppInfo.versionTuple
        let supported = ExploitSupportPolicy.isSupported(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
#if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--simulate-access") {
            exploitStatus = .success(method: "Simulator preview")
        }
#endif

        unsupportedMessage = supported ? nil : "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))"
        if let unsupportedMessage {
            exploitStatus = .unsupported(unsupportedMessage)
        }
    }
}
