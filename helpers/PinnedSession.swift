import CryptoKit
import Foundation
import Security

private final class PinningDelegate: NSObject, URLSessionDelegate {
    // RSA-2048 SubjectPublicKeyInfo ASN.1 wrapper (prepended to raw key bytes to form SPKI)
    private static let rsa2048Hdr: [UInt8] = [
        0x30, 0x82, 0x01, 0x22, 0x30, 0x0d, 0x06, 0x09,
        0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01,
        0x01, 0x05, 0x00, 0x03, 0x82, 0x01, 0x0f, 0x00
    ]

    // XOR-0x4B encoded SPKI SHA-256 hash of patches.cheatiosvip.net leaf public key
    // Decoded base64: ZeJnvZl3q0nLoMZ6yk6yIcvsMBNJwwli8BUN3zS0v4k=
    private static let _ph: [UInt8] = [
        0x11, 0x2E, 0x01, 0x25, 0x3D, 0x11, 0x27, 0x78,
        0x3A, 0x7B, 0x25, 0x07, 0x24, 0x06, 0x11, 0x7D,
        0x32, 0x20, 0x7D, 0x32, 0x02, 0x28, 0x3D, 0x38,
        0x06, 0x09, 0x05, 0x01, 0x3C, 0x3C, 0x27, 0x22,
        0x73, 0x09, 0x1E, 0x05, 0x78, 0x31, 0x18, 0x7B,
        0x3D, 0x7F, 0x20, 0x76
    ]

    private static let pinnedHash: Data = {
        let b64 = String(bytes: _ph.map { $0 ^ 0x4B }, encoding: .utf8) ?? ""
        return Data(base64Encoded: b64) ?? Data()
    }()

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition,
                                                   URLCredential?) -> Void) {
        // Only pin connections to our own server; let everything else use default trust
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              challenge.protectionSpace.host.hasSuffix("patches.cheatiosvip.net"),
              let serverTrust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        var cfError: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &cfError) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let chain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] ?? []
        guard let leaf = chain.first,
              let pubKey = SecCertificateCopyKey(leaf),
              let rawKey = SecKeyCopyExternalRepresentation(pubKey, nil) as Data?
        else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Build SPKI: prepend RSA-2048 header to raw key bytes, then SHA-256
        var spki = Data(Self.rsa2048Hdr)
        spki.append(rawKey)
        let digest = Data(SHA256.hash(data: spki))

        if digest == Self.pinnedHash {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

enum PinnedSession {
    static let shared: URLSession = {
        URLSession(configuration: .default,
                   delegate: PinningDelegate(),
                   delegateQueue: nil)
    }()
}
