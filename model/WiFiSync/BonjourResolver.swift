//
//  BonjourResolver.swift
//  Strongbox
//
//  Created by Strongbox on 11/01/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import dnssd
import Foundation
import Network







final class BonjourResolver: NSObject, NetServiceDelegate {
    enum BonjourResolverError: Error {
        case timeout
    }

    let timeoutSecs = DispatchTimeInterval.seconds(3) 

    static let resolverQ: DispatchQueue = .init(label: "BonjourResolver-DispatchQueue-Serial")

    typealias CompletionHandler = (Result<(String, UInt16), Error>) -> Void

    deinit {
        
        

        assert(self.refQ == nil)
        assert(self.completionHandler == nil)
    }

    private var refQ: DNSServiceRef? = nil
    private var completionHandler: CompletionHandler? = nil

    func start(endpoint: NWEndpoint, completionHandler: @escaping CompletionHandler) throws {
        guard case let .service(name: name, type: type, domain: domain, interface: interface) = endpoint,
              let interfaceIndex = UInt32(exactly: interface?.index ?? 0)
        else {
            throw NWError.posix(.EINVAL)
        }

        BonjourResolver.resolverQ.async { [weak self] in
            guard let self else { return }

            precondition(refQ == nil)

            self.completionHandler = completionHandler

            do {
                try resolve(name, type, domain, interfaceIndex)
            } catch {
                let completionHandler = completionHandler
                self.completionHandler = nil
                completionHandler(.failure(error))
            }
        }

        BonjourResolver.resolverQ.asyncAfter(deadline: .now() + timeoutSecs) { [weak self] in
            self?.timeout()
        }
    }

    private func resolve(_ name: String, _ type: String, _ domain: String, _ interfaceIndex: UInt32) throws {
        let context = Unmanaged.passUnretained(self)
        var refQLocal: DNSServiceRef? = nil

        var err = DNSServiceResolve(&refQLocal, 0, interfaceIndex, name, type, domain,
                                    { _, _, _, err, _, hostQ, port, _, _, context in
                                        let selfie = Unmanaged<BonjourResolver>.fromOpaque(context!).takeUnretainedValue()
                                        selfie.resolveDidComplete(err: err, hostQ: hostQ, port: UInt16(bigEndian: port))
                                    }, context.toOpaque())

        guard err == kDNSServiceErr_NoError else {
            throw NWError.dns(err)
        }

        let ref = refQLocal

        err = DNSServiceSetDispatchQueue(ref, BonjourResolver.resolverQ)

        guard err == kDNSServiceErr_NoError else {
            DNSServiceRefDeallocate(ref)
            throw NWError.dns(err)
        }

        

        refQ = ref
        _ = context.retain()
    }

    func timeout() {
        stop(with: .failure(BonjourResolverError.timeout))
    }

    func stop() {
        stop(with: .failure(CocoaError(.userCancelled)))
    }

    private func stop(with result: Result<(String, UInt16), Error>) {
        if let ref = refQ {
            refQ = nil
            DNSServiceRefDeallocate(ref)
            Unmanaged.passUnretained(self).release()
        }

        if let completionHandler {
            self.completionHandler = nil

            if case .failure(BonjourResolverError.timeout) = result {
                swlog("⚠️ Bonjour Resolver Timed Out")
            }

            completionHandler(result)
        }
    }

    private func resolveDidComplete(err: DNSServiceErrorType, hostQ: UnsafePointer<CChar>?, port: UInt16) {
        if err == kDNSServiceErr_NoError {
            stop(with: .success((String(cString: hostQ!), port)))
        } else {
            stop(with: .failure(NWError.dns(err)))
        }
    }
}
