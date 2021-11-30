//
//  UnifiedRecord.swift
//  MacBox
//
//  Created by Strongbox on 22/10/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

//import Cocoa

let recordTypeByTypeName : [String : RecordType]  = [
    "system.folder.SavedSearch" : .SavedSearch,
    "system.folder.Regular" : .RegularFolder,
    "webforms.WebForm" : .WebForm,
    "securenotes.SecureNote" : .SecureNote,
    "wallet.financial.CreditCard" : .CreditCard,
    "identities.Identity" : .Identity,
    "passwords.Password" : .Password,
    "wallet.financial.BankAccountUS" : .BankAccountUS,
    "wallet.computer.Database" : .Database,
    "wallet.government.DriversLicense" : .DriversLicense,
    "wallet.membership.Membership" : .Membership,
    "wallet.onlineservices.Email.v2" : .EmailV2,
    "wallet.government.HuntingLicense" : .HuntingLicense,
    "wallet.membership.RewardProgram" : .RewardProgram,
    "wallet.government.Passport" : .Passport,
    "wallet.computer.UnixServer" : .UnixServer,
    "wallet.government.SsnUS" : .SsnUS,
    "wallet.computer.Router" : .Router,
    "wallet.computer.License" : .License
]

class UnifiedRecord : Decodable {
    let typeName : String?
    let title : String?
    let createdAt : Date?
    let updatedAt : Date?
    var faveIndex : Int64? = 0
    var trashed : Bool? = false
    var location : String? = nil 

    var secureContents : SecureContents?
    var openContents : OpenContents?

    var type : RecordType {
        get {
            let maybeRecordType : RecordType? = typeName == nil ? .Unknown : recordTypeByTypeName [ typeName! ]
            if ( maybeRecordType == nil ) {
                print("⚠️ Unknown Record Type: \(String(describing: typeName))")
            }
            return maybeRecordType ?? .Unknown
        }
    }
    
    fileprivate func customizeIcon(_ recordType: RecordType, _ entry: Node) {
        entry.icon = NodeIcon.withPreset(recordType.icon().rawValue)
    }
    
    func getAlternativeUrlCount (_ entry : Node ) -> Int {
        return entry.fields.alternativeUrls.count
    }
    
    func addAlternativeUrl (_ entry : Node, url : String ) {
        let alternativeCount : Int = getAlternativeUrlCount ( entry )
        
        let newKey = "KP2A_URL_\(alternativeCount + 1)"
        
        entry.fields.setCustomField(newKey, value: StringValue(string: url))
    }
    
    func addUrl (_ entry : Node, url : String ) {
        guard !url.isEmpty else {
            return
        }
        
        if ( entry.fields.url == url ) {
            return
        }
        if ( entry.fields.alternativeUrls.contains( url )) {
            return;
        }
        
        if ( entry.fields.url.count > 0 ) {
            addAlternativeUrl ( entry, url: url )
        }
        else {
            entry.fields.url = url
        }
    }
    
    func fillStrongboxEntry(entry : Node) {
        if ( faveIndex != nil && faveIndex! > 0 ) {
            entry.fields.tags.add("Favorite") 
        }

        if ( createdAt != nil ) {
            entry.fields.setTouchPropertiesWithCreated(createdAt!, accessed: nil, modified: nil, locationChanged: nil, usageCount: nil)
        }

        if ( updatedAt != nil ) {
            entry.fields.setModifiedDateExplicit(updatedAt!)
        }

        let canonicalUrl : String =  self.location ?? "";
        
        if ( canonicalUrl.count > 0 ) {
            addUrl(entry, url: canonicalUrl)
        }
        
        if ( title != nil ) {
            entry.setTitle(title!, keePassGroupTitleRules: true)
        }
        
        customizeIcon(type, entry)
        
        if ( openContents != nil ) {
            if ( openContents!.tags != nil ) {
                entry.fields.tags.addObjects(from: openContents!.tags ?? [])
            }
        }
        
        if ( secureContents != nil ) {
            entry.fields.notes = secureContents?.notesPlain ?? ""
        
            
            
            if ( secureContents!.fields != nil ) {
                let fields : [Field] = secureContents!.fields!
                
                for field in fields {
                    addField(entry, field: field)
                }
            }
            
            
            
            if ( secureContents!.URLs != nil ) {
                let urls : [[String : String]] = secureContents!.URLs!
                
                for url in urls {
                    let theUrl : String = url["url"] ?? ""
                    
                    if ( theUrl.count > 0 ) {
                        addUrl(entry, url: theUrl )
                    }
                }
            }
            
            

            if ( secureContents!.sections != nil ) {
                for section in secureContents!.sections! {
                    if ( section.fields != nil ) {
                        for field in section.fields! {
                            addSectionField(entry, field: field)
                        }
                    }
                }
            }
            
            
            
            if ( secureContents!.password != nil && secureContents!.password!.count > 0 ) {
                entry.fields.password = secureContents!.password!
            }
        }
    }
    
    func addField ( _ entry : Node, field : Field ) {
        guard let value = field.value, let name = field.name else {
            return
        }
        
        if ( field.designation == "password") {
            let password = value.value as? String
            if ( password != nil ) {
                if ( password!.count > 0 ) {
                    entry.fields.password = password!
                }
            }
        }
        else if ( field.designation == "username" ) {
            let username = value.value as? String
            if ( username != nil ) {
                if ( username!.count > 0 ) {
                    entry.fields.username = username!
                }
            }
        }
        else {
            let val = value.value as? String

            if ( val != nil && val!.count > 0 && name.count > 0 ) {
                entry.fields.setCustomField(name, value: StringValue(string: val!))
            }
        }
    }
    
    fileprivate func addDateStringField(_ epoch: Int64, _ title: String, _ entry: Node) {
        let date = Date(timeIntervalSince1970: TimeInterval(epoch))
        let mydf = DateFormatter()
        mydf.dateStyle = .long 
        let dateFmt = mydf.string(from: date)

        addEntryField(entry, title, dateFmt)
    }
    
    func addSectionField ( _ entry : Node, field : SectionField ) {
        guard let value = field.v, let title = field.t, let datatype = field.k, let name = field.n else {
            return;
        }
        
        let stringValue = (value.value as? String) ?? ""

        switch datatype {
        case "concealed":
            if ( !stringValue.isEmpty ) {
                let isAlternativeTotpStyle = name.starts(with: "TOTP_")
                let isTotpUrl = stringValue.starts(with: "otpauth:
                
                if ( isTotpUrl ) {
                    let url = URL(string: stringValue)
                    
                    if ( url == nil ) {
                        addEntryField(entry, "Invalid-Imported-TOTP-URL", stringValue, true)
                    }
                    else {
                        let token = url != nil ? OTPToken(url: url, secret: nil) : nil
                        
                        if ( token != nil && entry.fields.otpToken == nil ) {
                            entry.fields.setTotp(token!, appendUrlToNotes: false, addLegacyFields: false, addOtpAuthUrl: false)
                        }
                        else {
                            addEntryField(entry, "Alternative-TOTP", stringValue, true)
                        }
                    }
                }
                else if ( isAlternativeTotpStyle ) {
                    let secretData = NSData.secret(with: stringValue)
                    
                    var token : OTPToken? = nil
                    if( secretData != nil ) {
                        let tmp = OTPToken(type: OTPTokenType.timer, secret: secretData, name: "TOTP", issuer: "TOTP")
                        if ( tmp != nil && tmp!.validate() ) {
                            token = tmp
                        }
                        else {
                            token = nil
                        }
                    }

                    if ( token != nil && entry.fields.otpToken == nil ) {
                        entry.fields.setTotp(token!, appendUrlToNotes: false, addLegacyFields: false, addOtpAuthUrl: false)
                    }
                    else {
                        addEntryField(entry, "Alternative-TOTP", stringValue, true)
                    }
                }
                else {

                    addEntryField(entry, title, stringValue, true)
                }
            }
            break
        case "monthYear":
            let number : Int64? = value.value as? Int64
            if ( number != nil ) {
                let year = number! / 100
                let month = number! % 100
                let stringExpiry = String(format: "%02d/%04d", month, year)
                addEntryField(entry, title, stringExpiry)
            }
            break
        case "date":










                let epoch: Int64? = value.value as? Int64
                
            if( epoch != nil ) {




                addDateStringField(epoch!, title, entry)

            }
            else {
                print("🔴 Unknown Date format value: [\(title)] = [\(stringValue)] with type [\(String(describing: datatype))]")
            }


        case "string", "phone", "menu", "cctype", "gender", "email":
            if ( !stringValue.isEmpty ) {

                addEntryField(entry, title, stringValue)
            }
            break
        case "address":
            let lines : [String:Any] = value.value as! [String:Any]
            
            for line in lines {
                if ( !line.key.isEmpty ) {
                    let stringValue = String(describing: line.value);
                    if ( !stringValue.isEmpty ) {

                        addEntryField(entry, line.key, stringValue)
                    }
                }
            }
            break
        case "URL":
            if ( !stringValue.isEmpty ) {

                addUrl(entry, url: stringValue)
            }
            break
        case "file":
            
            break
        default:

            addEntryField(entry, title, stringValue)
        }
    }
    
    func addEntryField (_ entry : Node, _ key : String, _ value : String, _ concealed : Bool = false ) {
        if ( value.count > 0 ) {
            if ( key == "username" ) {
                if ( entry.fields.username.count == 0 ) {
                    entry.fields.username = value
                    return
                }
                else {
                    let uniqueKey = key + "-" + UUID().uuidString
                    entry.fields.setCustomField(uniqueKey, value: StringValue(string: value, protected: concealed ))
                    return
                }
            }
            else if ( key == "password" ) {
                if ( entry.fields.password.count == 0 ) {
                    entry.fields.password = value
                    return
                }
                else {
                    let uniqueKey = key + "-" + UUID().uuidString
                    entry.fields.setCustomField(uniqueKey, value: StringValue(string: value, protected: concealed ))
                    return
                }
            }
            else if ( key == "url" ) { 
                addUrl(entry, url: value)
                return
            }
        }
        
        if ( key.count == 0 || entry.fields.customFields.keys.contains(key) ) {
            let uniqueKey = key + "-" + UUID().uuidString
            entry.fields.setCustomField(uniqueKey, value: StringValue(string: value, protected: concealed ))
        }
        else {
            entry.fields.setCustomField(key, value: StringValue(string: value, protected: concealed ))
        }
    }
}
