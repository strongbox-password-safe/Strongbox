//
//  WifiSyncProtocol.swift
//  WeeFee-Server
//
//  Created by Strongbox on 07/12/2023.
//

import Foundation
import Network

enum WiFiSyncMessageType: UInt32 {
    case invalid = 0
    case listDatabasesRequest = 1
    case listDatabasesResponse = 2
    case getDatabaseRequest = 3
    case getDatabaseResponse = 4
    case pushDatabaseRequest = 5
    case pushDatabaseResponse = 6
}

class WifiSyncProtocol: NWProtocolFramerImplementation {
    static let definition = NWProtocolFramer.Definition(implementation: WifiSyncProtocol.self)

    static var label: String { "Strongbox Wi-Fi Sync" }

    required init(framer _: NWProtocolFramer.Instance) {}
    func start(framer _: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult { .ready }
    func wakeup(framer _: NWProtocolFramer.Instance) {}
    func stop(framer _: NWProtocolFramer.Instance) -> Bool { true }
    func cleanup(framer _: NWProtocolFramer.Instance) {}

    func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message, messageLength: Int, isComplete _: Bool) {


        let type = message.wifiSyncMessageType
        let header = WiFiSyncProtocolHeader(type: type.rawValue, length: UInt32(messageLength))

        framer.writeOutput(data: header.encodedData)

        do {
            try framer.writeOutputNoCopy(length: messageLength)
        } catch {
            swlog("🔴 error writing \(error)")
        }
    }

    func handleInput(framer: NWProtocolFramer.Instance) -> Int {
        while true {
            var tempHeader: WiFiSyncProtocolHeader? = nil
            let headerSize = WiFiSyncProtocolHeader.encodedSize
            let parsed = framer.parseInput(minimumIncompleteLength: headerSize,
                                           maximumLength: headerSize)
            { buffer, _ -> Int in


                guard let buffer else {
                    return 0
                }



                if buffer.count < headerSize {
                    return 0
                }
                tempHeader = WiFiSyncProtocolHeader(buffer)
                return headerSize
            }

            guard parsed, let header = tempHeader else {
                return headerSize
            }

            var messageType = WiFiSyncMessageType.invalid
            if let parsedMessageType = WiFiSyncMessageType(rawValue: header.type) {
                messageType = parsedMessageType
            }
            let message = NWProtocolFramer.Message(wiFiSyncMessageType: messageType)

            if !framer.deliverInputNoCopy(length: Int(header.length), message: message, isComplete: true) {
                return 0
            }
        }
    }
}

extension NWProtocolFramer.Message {
    convenience init(wiFiSyncMessageType: WiFiSyncMessageType) {
        self.init(definition: WifiSyncProtocol.definition)
        self["WiFiSyncMessageType"] = wiFiSyncMessageType
    }

    var wifiSyncMessageType: WiFiSyncMessageType {
        if let type = self["WiFiSyncMessageType"] as? WiFiSyncMessageType {
            return type
        } else {
            return .invalid
        }
    }
}

struct WiFiSyncProtocolHeader: Codable {
    let type: UInt32
    let length: UInt32

    init(type: UInt32, length: UInt32) {
        self.type = type
        self.length = length
    }

    init(_ buffer: UnsafeMutableRawBufferPointer) {
        var tempType: UInt32 = 0
        var tempLength: UInt32 = 0
        withUnsafeMutableBytes(of: &tempType) { typePtr in
            typePtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: 0),
                                                            count: MemoryLayout<UInt32>.size))
        }
        withUnsafeMutableBytes(of: &tempLength) { lengthPtr in
            lengthPtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: MemoryLayout<UInt32>.size),
                                                              count: MemoryLayout<UInt32>.size))
        }
        type = tempType
        length = tempLength
    }

    var encodedData: Data {
        var tempType = type
        var tempLength = length
        var data = Data(bytes: &tempType, count: MemoryLayout<UInt32>.size)
        data.append(Data(bytes: &tempLength, count: MemoryLayout<UInt32>.size))
        return data
    }

    static var encodedSize: Int {
        MemoryLayout<UInt32>.size * 2
    }
}
