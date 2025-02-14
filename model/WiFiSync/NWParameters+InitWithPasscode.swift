//
//  NWParameters+InitWithPasscode.swift
//  WeeFee-Server
//
//  Created by Strongbox on 07/12/2023.
//

import CryptoKit
import Network

extension NWParameters {
    static let ServiceName = "Strongbox-Wi-Fi-Sync"

    convenience init(passcode: String) {
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableKeepalive = false
        tcpOptions.keepaliveIdle = 0
        tcpOptions.connectionTimeout = 2

        self.init(tls: NWParameters.tlsOptions(passcode: passcode), tcp: tcpOptions)

        includePeerToPeer = false

        let options = NWProtocolFramer.Options(definition: WifiSyncProtocol.definition)

        defaultProtocolStack.applicationProtocols.insert(options, at: 0)
    }

    private static func tlsOptions(passcode: String) -> NWProtocolTLS.Options {
        let tlsOptions = NWProtocolTLS.Options()

        let authenticationKey = SymmetricKey(data: passcode.data(using: .utf8)!)
        let authenticationCode = HMAC<SHA256>.authenticationCode(for: NWParameters.ServiceName.data(using: .utf8)!, using: authenticationKey)

        let authenticationDispatchData = authenticationCode.withUnsafeBytes {
            DispatchData(bytes: $0)
        }

        sec_protocol_options_add_pre_shared_key(tlsOptions.securityProtocolOptions,
                                                authenticationDispatchData as __DispatchData,
                                                stringToDispatchData(NWParameters.ServiceName)! as __DispatchData)

        sec_protocol_options_append_tls_ciphersuite(tlsOptions.securityProtocolOptions,
                                                    tls_ciphersuite_t(rawValue: UInt16(TLS_PSK_WITH_AES_128_GCM_SHA256))!)

        return tlsOptions
    }

    private static func stringToDispatchData(_ string: String) -> DispatchData? {
        guard let stringData = string.data(using: .utf8) else {
            return nil
        }
        let dispatchData = stringData.withUnsafeBytes {
            DispatchData(bytes: $0)
        }
        return dispatchData
    }
}
