//
//  AutoFillEncryptedRequest.swift
//  MacBox
//
//  Created by Strongbox on 24/08/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Foundation
import CryptoKit

@objc
enum AutoFillMessageType : NSInteger, Codable {
    case status
    case search
    case getCredentialsForUrl
    case copyField
}

@objc
class AutoFillEncryptedRequest : NSObject, Codable {
    @objc var clientPublicKey : String = ""
    @objc var nonce : String = ""
    @objc var message : String = ""
    @objc var messageType : AutoFillMessageType = .status
    
    @objc
    class func from ( json : String ) -> AutoFillEncryptedRequest? {
        let decoder = JSONDecoder()
        
        guard let data = json.data(using: .utf8),
              let encryptedRequest = try? decoder.decode(AutoFillEncryptedRequest.self, from: data) else {
            NSLog("🔴 Could not decode AutoFillEncryptedRequest object from JSON");
            return nil 
        }
                
        return encryptedRequest;
    }
    
    func decryptMessage ( keyPair : BoxKeyPair ) -> String? {
        if ( message.count > 0 ) {
            return CryptoBoxHelper.unSeal(message, nonce: nonce, theirPublicKey: clientPublicKey, myPrivateKey: keyPair.privateKey)
        }
        else {
            return ""
        }
    }
}

@objc
class AutoFillEncryptedResponse : NSObject, Codable {
    @objc var success : Bool = false
    @objc var errorMessage : String = ""
    @objc var serverPublicKey : String = ""
    @objc var message : String = ""
    @objc var nonce : String = ""
    
    class func error ( message : String ) -> AutoFillEncryptedResponse {
        let ret = AutoFillEncryptedResponse( )
        
        ret.success = false
        ret.errorMessage = message
        ret.serverPublicKey = "";

        return ret;
    }
    
    class func successWithResult ( resultJson : String, clientPublicKey : String, keyPair : BoxKeyPair ) -> AutoFillEncryptedResponse  {        
        let nonce = CryptoBoxHelper.createNonce();
        
        guard let cipherText = CryptoBoxHelper.seal(resultJson, nonce: nonce, theirPublicKey: clientPublicKey, myPrivateKey: keyPair.privateKey) else {
            return error(message: "Could not seal with crypto box.")
        }
        
        let ret = AutoFillEncryptedResponse()
        
        ret.success = true
        ret.message = cipherText;
        ret.nonce = nonce;
        ret.serverPublicKey = keyPair.publicKey;
        
        return ret;
    }
    
    @objc func toJson () -> String {
        return AutoFillJsonHelper.toJson(object: self)
    }
}

class AutoFillJsonHelper {
    class func toJson<T: Codable> ( object : T ) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let encodedData = try? encoder.encode(object),
              let jsonString = String(data: encodedData, encoding: .utf8) else {
            NSLog("🔴 Could not encode to JSON");
            return "{ \"error\" : \"🔴 Could not encode to JSON\" }"
        }
        
        return jsonString
    }
}
