//
//  NodeFields.m
//  MacBox
//
//  Created by Mark on 31/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "NodeFields.h"
#import "NSArray+Extensions.h"
#import "NSDictionary+Extensions.h"
#import "Utils.h"

#import "OTPToken+Serialization.h"
#import "OTPToken+Generation.h"
#import "NSURL+QueryItems.h"
#import "MMcG_MF_Base32Additions.h"

static NSString* const kOtpAuthScheme = @"otpauth";
static NSString* const kKeePassXcTotpSeedKey = @"TOTP Seed";
static NSString* const kKeePassXcTotpSettingsKey = @"TOTP Settings";
static NSString* const kKeeOtpPluginKey = @"otp";

@interface NodeFields ()

@property BOOL hasCachedOtpToken;
@property OTPToken* cachedOtpToken;
@property NSMutableDictionary<NSString*, StringValue*> *mutableCustomFields;
@property BOOL usingLegacyKeeOtpStyle;

@end

@implementation NodeFields

+ (NSRegularExpression *)totpNotesRegex {
    static NSRegularExpression *_regex;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        _regex = [NSRegularExpression regularExpressionWithPattern:@"\n-----------------------------------------\nStrongbox TOTP Auth URL: \\[.*\\]" options:NSRegularExpressionDotMatchesLineSeparators error:Nil];
    });
    
    return _regex;
}

+ (BOOL)isTotpCustomFieldKey:(NSString*)key {
    return [key isEqualToString:kKeeOtpPluginKey] || [key isEqualToString:kKeePassXcTotpSeedKey] || [key isEqualToString:kKeePassXcTotpSettingsKey];
}

- (instancetype _Nullable)init {
    return [self initWithUsername:@""
                              url:@""
                         password:@""
                            notes:@""
                            email:@""];
}

- (instancetype _Nullable)initWithUsername:(NSString*_Nonnull)username
                                       url:(NSString*_Nonnull)url
                                  password:(NSString*_Nonnull)password
                                     notes:(NSString*_Nonnull)notes
                                     email:(NSString*_Nonnull)email {
    if (self = [super init]) {
        self.username = username == nil ? @"" : username;
        self.url = url == nil ? @"" : url;
        self.password = password == nil ? @"" : password;
        self.notes = notes == nil ? @"" : notes;
        self.email = email == nil ? @"" : email;
        self.passwordHistory = [[PasswordHistory alloc] init];
        
        NSDate* date = [NSDate date];
        
        _modified = date;
        _accessed = date;
        _locationChanged = date;
        _usageCount = @(0);
        _created = date;
        
        self.passwordModified = date;
        self.attachments = [NSMutableArray array];
        self.mutableCustomFields = [NSMutableDictionary dictionary];
        self.keePassHistory = [NSMutableArray array];
        self.tags = [NSMutableSet set];
    }
    
    return self;
}

- (NSMutableArray<NodeFileAttachment*>*)cloneAttachments {
    return [[self.attachments map:^id _Nonnull(NodeFileAttachment * _Nonnull obj, NSUInteger idx) {
        return [NodeFileAttachment attachmentWithName:obj.filename index:obj.index linkedObject:obj.linkedObject];
    }] mutableCopy];
}

- (NSMutableDictionary<NSString*, StringValue*>*)cloneCustomFields {
    NSMutableDictionary<NSString*, StringValue*>* ret = [NSMutableDictionary dictionaryWithCapacity:self.customFields.count];
    
    for (NSString* key in self.customFields.allKeys) {
        StringValue* orig = self.customFields[key];
        ret[key] = [StringValue valueWithString:orig.value protected:orig.protected];
    }
    
    return ret;
}

+ (NodeFields *)deserialize:(NSDictionary *)dict {
    NSString* username = dict[@"username"];
    NSString* url = dict[@"url"];
    NSString* password = dict[@"password"];
    NSString* notes = dict[@"notes"];
    NSString* email = dict[@"email"];
    NSNumber* passwordModified = dict[@"passwordModified"];
    NSNumber* expires = dict[@"expires"];
    
    NSArray<NSDictionary*>* attachments = dict[@"attachments"];
    NSArray<NSDictionary*>* customFields = dict[@"customFields"];

    NSArray<NSString*>* tagsArray = dict[@"tags"]; // Must be an array to serialize correctly to JSON!

    NodeFields* ret = [[NodeFields alloc] initWithUsername:username
                                                       url:url
                                                  password:password
                                                     notes:notes
                                                     email:email];

    ret.tags = [NSMutableSet setWithArray:tagsArray];
    
    ret.passwordModified = passwordModified != nil ? [NSDate dateWithTimeIntervalSince1970:passwordModified.unsignedIntegerValue] : nil;
    ret.expires = expires != nil ? [NSDate dateWithTimeIntervalSince1970:expires.unsignedIntegerValue] : nil;
    
    // Attachments... These need to be fixed up to fit into destination
    
    NSArray<NodeFileAttachment*>* nfas = [attachments map:^id _Nonnull(NSDictionary * _Nonnull obj, NSUInteger idx) {
        NSString* filename = obj.allKeys.firstObject;
        NSNumber* index = obj[filename];
        
        return [NodeFileAttachment attachmentWithName:filename index:index.unsignedIntValue linkedObject:nil];
    }];
    [ret.attachments addObjectsFromArray:nfas];
    
    // Custom Fields
    
    for (NSDictionary* obj in customFields) {
        NSString* key = obj[@"key"];
        NSString* value = obj[@"value"];
        NSNumber* protected = obj[@"protected"];
        [ret setCustomField:key value:[StringValue valueWithString:value protected:protected.boolValue]];
    }
    
    return ret;
}

- (NSDictionary *)serialize:(SerializationPackage *)serialization {
    NSMutableDictionary* ret = [NSMutableDictionary dictionary];
    
    ret[@"username"] = self.username;
    ret[@"url"] = self.url;
    ret[@"password"] = self.password;
    ret[@"notes"] = self.notes;
    ret[@"email"] = self.email;
    
    if(self.passwordModified) {
        ret[@"passwordModified"] = @((NSUInteger)[self.passwordModified timeIntervalSince1970]);
    }
    if(self.expires) {
        ret[@"expires"] = @((NSUInteger)[self.expires timeIntervalSince1970]);
    }

    NSArray<NSDictionary*>* attachments = [self.attachments map:^id _Nonnull(NodeFileAttachment * _Nonnull obj, NSUInteger idx) {
        [serialization.usedAttachmentIndices addObject:@(obj.index)];
        return @{ obj.filename : @(obj.index) };
    }];
    ret[@"attachments"] = attachments;
    
    NSArray<NSDictionary*>* customFields = [self.customFields.allKeys map:^id _Nonnull(NSString * _Nonnull key, NSUInteger idx) {
        StringValue* value = self.customFields[key];
        return @{ @"key" : key, @"value" : value.value, @"protected" : @(value.protected) };
    }];
    
    ret[@"customFields"] = customFields;
    
    // Tags
    
    ret[@"tags"] = self.tags.allObjects;
    
    return ret;
}

- (NodeFields*)cloneOrDuplicate:(BOOL)clearHistory cloneTouchProperties:(BOOL)cloneMetadataDates {
    NodeFields* ret = [[NodeFields alloc] initWithUsername:self.username
                                                       url:self.url
                                                  password:self.password
                                                     notes:self.notes
                                                     email:self.email];
    
    ret.expires = self.expires;
    ret.passwordModified = self.passwordModified;

    if (cloneMetadataDates) {
        [ret setTouchPropertiesWithCreated:self.created accessed:self.accessed modified:self.modified locationChanged:self.locationChanged usageCount:self.usageCount];
    }

    ret.attachments = [self cloneAttachments];
    ret.mutableCustomFields = [self cloneCustomFields];
    ret.tags = self.tags.mutableCopy;

    if (clearHistory) {
        ret.keePassHistory = [NSMutableArray array];
    }
    else {
        ret.keePassHistory = self.keePassHistory.mutableCopy;
    }
    
    return ret;
}

- (void)setPassword:(NSString *)password {
    if([password isEqualToString:_password]) {
        return;
    }
    
    _password = password;
    self.passwordModified = [NSDate date];
    
    PasswordHistory *pwHistory = self.passwordHistory;
    
    if (pwHistory.enabled && pwHistory.maximumSize > 0 && password) {
        [pwHistory.entries addObject:[[PasswordHistoryEntry alloc] initWithPassword:password]];
        
        if ((pwHistory.entries).count > pwHistory.maximumSize) {
            NSUInteger count = (pwHistory.entries).count;
            NSArray *slice = [pwHistory.entries subarrayWithRange:(NSRange) {count - pwHistory.maximumSize, pwHistory.maximumSize }];
            [pwHistory.entries removeAllObjects];
            [pwHistory.entries addObjectsFromArray:slice];
        }
    }
    
    self.hasCachedOtpToken = NO; // Force Reload of TOTP as may have changed with this change
}

- (void)setNotes:(NSString *)notes {
    if([notes isEqualToString:_notes]) {
        return;
    }
    
    _notes = notes;
    self.hasCachedOtpToken = NO; // Force Reload of TOTP as may have changed with this change
}

- (NSDictionary<NSString *,StringValue *> *)customFields {
    return [self.mutableCustomFields copy];
}

- (void)setCustomFields:(NSDictionary<NSString *,StringValue *> *)customFields {
    self.mutableCustomFields = [customFields mutableCopy];
    self.hasCachedOtpToken = NO; // Force Reload of TOTP as may have changed with this change
}

- (void)removeAllCustomFields {
    [self.mutableCustomFields removeAllObjects];
    self.hasCachedOtpToken = NO; // Force Reload of TOTP as may have changed with this change
}

- (void)removeCustomField:(NSString*)key {
    [self.mutableCustomFields removeObjectForKey:key];
    self.hasCachedOtpToken = NO; // Force Reload of TOTP as may have changed with this change
}

- (void)setCustomField:(NSString*)key value:(StringValue*)value {
    self.mutableCustomFields[key] = value;
    self.hasCachedOtpToken = NO; // Force Reload of TOTP as may have changed with this change
}

- (void)touch:(BOOL)modified {
    _usageCount = self.usageCount != nil ? @(self.usageCount.integerValue + 1) : @(1);

    NSDate *now = NSDate.date;
    _accessed = now;
    
    if(modified) {
        [self setModifiedDateExplicit:now];
    }
}

- (void)touchLocationChanged {
    [self setTouchPropertiesWithCreated:nil accessed:nil modified:nil locationChanged:NSDate.date usageCount:nil];
}

- (void)setModifiedDateExplicit:(NSDate*)modified {
    [self setTouchPropertiesWithCreated:nil accessed:modified modified:modified locationChanged:nil usageCount:nil];
}

- (void)setTouchPropertiesWithAccessed:(NSDate*)accessed modified:(NSDate*)modified usageCount:(NSNumber*)usageCount {
    [self setTouchPropertiesWithCreated:nil accessed:accessed modified:modified locationChanged:nil usageCount:usageCount];
}

- (void)setTouchPropertiesWithCreated:(NSDate*)created accessed:(NSDate*)accessed modified:(NSDate*)modified locationChanged:(NSDate*)locationChanged usageCount:(NSNumber*)usageCount {
    if (created != nil) _created = created;
    
    if (accessed != nil) _accessed = accessed;
    
    if (modified != nil) _modified = modified;
    
    if (locationChanged != nil) _locationChanged = locationChanged;

    if (usageCount != nil) _usageCount = usageCount;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// TOTP

- (OTPToken *)otpToken {
    if(!self.hasCachedOtpToken) {
        BOOL usingLegacyKeeOtpStyle = NO;
        self.cachedOtpToken = [NodeFields getOtpTokenFromRecord:self.password fields:self.customFields notes:self.notes usingLegacyKeeOtpStyle:&usingLegacyKeeOtpStyle];
        self.usingLegacyKeeOtpStyle = usingLegacyKeeOtpStyle;
        self.hasCachedOtpToken = YES;
    }
    
    return self.cachedOtpToken;
}

+ (OTPToken*)getOtpTokenFromString:(NSString * _Nonnull)string
                        forceSteam:(BOOL)forceSteam
                            issuer:(NSString*)issuer
                          username:(NSString*)username {
    OTPToken *token = nil;
    NSURL *url = [NodeFields findOtpUrlInString:string];
    
    if(url) {
        token = [NodeFields getOtpTokenFromUrl:url];
    }
    else {
        NSData* secretData = [NSData secretWithString:string];
        if(secretData) {
            token = [OTPToken tokenWithType:OTPTokenTypeTimer secret:secretData name:username issuer:issuer];
            token = [token validate] ? token : nil;
        }
    }
    
    if(forceSteam) {
        token.algorithm = OTPAlgorithmSteam;
        token.digits = 5;
    }
    
    return token;
}

- (void)setTotp:(OTPToken*)token appendUrlToNotes:(BOOL)appendUrlToNotes {
    // Notes Field if it's a Password Safe/KeePass1 database
    
    if(appendUrlToNotes) {
        self.notes = [self.notes stringByAppendingFormat:@"\n-----------------------------------------\nStrongbox TOTP Auth URL: [%@]", [token url:YES]];
    }
    else {
        // Set Common TOTP Fields..
        // KeePassXC Legacy...
        
        self.mutableCustomFields[kKeePassXcTotpSeedKey] = [StringValue valueWithString:[token.secret mmcg_base32String] protected:YES];
        
        if(token.algorithm == OTPAlgorithmSteam) {
            NSString* valueString = [NSString stringWithFormat:@"%lu;S", (unsigned long)token.period];
            self.mutableCustomFields[kKeePassXcTotpSettingsKey] = [StringValue valueWithString:valueString protected:YES];
        }
        else {
            NSString* valueString = [NSString stringWithFormat:@"%lu;%lu", (unsigned long)token.period, (unsigned long)token.digits];
            self.mutableCustomFields[kKeePassXcTotpSettingsKey] = [StringValue valueWithString:valueString protected:YES];
        }
        
        // KeeOtp Plugin (And now new KeePassXC Style)...
        //
        // MMcG: 22-Nov-2019 - KeePassXC now uses this key and stores an OTPAUTH URL in there...
        // If the style is old KeeOTP then keep it like that, otherwise if it's new/empty or using
        // and OTPAuth then use that new style... hopefully KeeOTP guys will move to new OTP System...
        //
        // * otp="key=2GQFLXXUBJQELC&step=31"
        
        if(self.usingLegacyKeeOtpStyle) {
            NSURLComponents *components = [NSURLComponents componentsWithString:@"http://strongboxsafe.com"];
            NSURLQueryItem *key = [NSURLQueryItem queryItemWithName:@"key" value:[token.secret mmcg_base32String]];
            
            if(token.period != OTPToken.defaultPeriod || token.digits != OTPToken.defaultDigits) {
                NSURLQueryItem *step = [NSURLQueryItem queryItemWithName:@"step" value:[NSString stringWithFormat: @"%lu", (unsigned long)token.period]];
                NSURLQueryItem *size = [NSURLQueryItem queryItemWithName:@"size" value:[NSString stringWithFormat: @"%lu", (unsigned long)token.digits]];
                components.queryItems = @[key, step, size];
            }
            else {
                components.queryItems = @[key];
            }
            self.mutableCustomFields[kKeeOtpPluginKey] = [StringValue valueWithString:components.query protected:YES];
        }
        else {
            NSURL* otpauthUrl = [token url:YES];
            self.mutableCustomFields[kKeeOtpPluginKey] = [StringValue valueWithString:otpauthUrl.absoluteString protected:YES];
        }
    }
    
    self.hasCachedOtpToken = NO; // Force Reload of TOTP as may have changed with this change
}

- (void)clearTotp {
    // Set Common TOTP Fields.. and append to Notes if asked to (usually for Password Safe dbs)
    
    // KeePassXC Otp
    
    self.mutableCustomFields[kKeePassXcTotpSeedKey] = nil;
    self.mutableCustomFields[kKeePassXcTotpSettingsKey] = nil;
    
    // KeeOtp Plugin
    // * otp="key=2GQFLXXUBJQELC&step=31"
    
    self.mutableCustomFields[kKeeOtpPluginKey] = nil;
    
    // Notes Field if it's a Password Safe database
    
    NSTextCheckingResult *result = [[NodeFields totpNotesRegex] firstMatchInString:self.notes options:kNilOptions range:NSMakeRange(0, self.notes.length)];
    
    if(result) {
        NSLog(@"Found matching OTP in Notes: [%@]", [self.notes substringWithRange:result.range]);
        self.notes = [self.notes stringByReplacingCharactersInRange:result.range withString:@""];
    }
    
    self.hasCachedOtpToken = NO; // Force Reload of TOTP as may have changed with this change
}

+ (NSDictionary<NSString*, NSString*>*)getQueryParams:(NSString*)queryString {
    NSURLComponents *components = [NSURLComponents new];
    [components setQuery:queryString];
    NSArray *queryItems = components.queryItems;
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithCapacity:queryItems.count];
    for (NSURLQueryItem *item in queryItems) {
        params[item.name] = item.value;
    }
    
    return params;
}

+ (OTPToken*)getOtpTokenFromUrl:(NSURL*)url {
    if(url && url.scheme && [url.scheme isEqualToString:kOtpAuthScheme]) {
        OTPToken* ret = [OTPToken tokenWithURL:url];
        NSDictionary *params = [NodeFields getQueryParams:url.query];
        if(params[@"encoder"] && [params[@"encoder"] isEqualToString:@"steam"]) {
            //            NSLog(@"Steam Encoder on OTPAuth URL Found");
            ret.algorithm = OTPAlgorithmSteam;
            ret.digits = 5;
        }
        
        return ret;
    }
    
    return nil;
}

+ (OTPToken*)getOtpTokenFromRecord:(NSString*)password
                            fields:(NSDictionary<NSString*, StringValue*>*)fields
                             notes:(NSString*)notes
            usingLegacyKeeOtpStyle:(BOOL*)usingLegacyKeeOtpStyle {
    // Good reference for OTPAuth URL here: https://github.com/google/google-authenticator/wiki/Key-Uri-Format
    
    // KyPass and others... - OTPAuth url in the Password field…
    
    NSURL *otpUrl = [NSURL URLWithString:password];
    OTPToken* ret = [NodeFields getOtpTokenFromUrl:otpUrl];
    if(ret) {
        return ret;
    }

    // KeeOtp Plugin and new KeePassXC system...
    
    ret = [NodeFields getKeeOtpAndNewKeePassXCToken:fields usingLegacyKeeOtpStyle:usingLegacyKeeOtpStyle];
    if(ret) {
        return ret;
    }

    // KeePassXC Legacy
    
    ret = [NodeFields getKeePassXCLegacyOTPToken:fields];
    if(ret) {
        return ret;
    }

    // Lastly... See if we can find an OTPAuth URL in the Notes field...
    
    NSURL *url = [NodeFields findOtpUrlInString:notes];
    
    return [NodeFields getOtpTokenFromUrl:url];
}

+ (OTPToken*)getKeePassXCLegacyOTPToken:(NSDictionary<NSString*, StringValue*>*)fields {
    // KeePassXC - MMcG 22-Nov-2019 - This seems to have become legacy and the KeePassXC Crew have moved to using the "OTP" (formerly KeeOTP owned) field to store an OTPAUTH URL...
    //
    // * []TOTP Seed=<seed>
    // * []TOTP Settings=30;6 - time and digits - can be 30;S for “Steam”
    
    StringValue* keePassXcOtpSecretEntry = fields[kKeePassXcTotpSeedKey];
    
    if(keePassXcOtpSecretEntry) {
        NSString* keePassXcOtpSecret = keePassXcOtpSecretEntry.value;
        if(keePassXcOtpSecret) {
            OTPToken* token = [OTPToken tokenWithType:OTPTokenTypeTimer secret:[NSData secretWithString:keePassXcOtpSecret] name:@"<Unknown>" issuer:@"<Unknown>"];
            
            StringValue* keePassXcOtpParamsEntry = fields[kKeePassXcTotpSettingsKey];
            
            if(keePassXcOtpParamsEntry) {
                NSString* keePassXcOtpParams = keePassXcOtpParamsEntry.value;
                if(keePassXcOtpParams) {
                    NSArray<NSString*>* params = [keePassXcOtpParams componentsSeparatedByString:@";"];
                    if(params.count > 0) {
                        token.period = [params[0] integerValue];
                    }
                    if(params.count > 1) {
                        if(![params[1] isEqualToString:@"S"]) { // S = Steam
                            token.digits = [params[1] integerValue];
                        }
                        else {
                            token.digits = 5;
                            token.algorithm = OTPAlgorithmSteam;
                        }
                    }
                }
            }
            
            if([token validate])
            {
                return token;
            }
        }
    }

    return nil;
}

+ (nullable OTPToken*)getOtpTokenFromRecord:(NSString*)password fields:(NSDictionary*)fields notes:(NSString*)notes {
    BOOL usingLegacyKeeOtpStyle;
    return [NodeFields getOtpTokenFromRecord:password fields:fields notes:notes usingLegacyKeeOtpStyle:&usingLegacyKeeOtpStyle];
}

+ (OTPToken*)getKeeOtpAndNewKeePassXCToken:(NSDictionary<NSString*, StringValue*>*)fields usingLegacyKeeOtpStyle:(BOOL*)usingLegacyKeeOtpStyle {
    // KeeOtp Plugin
    // * otp="key=2GQFLXXUBJQELC&step=31"
    // * otp="key=2GQFLXXUBJQELC&size=8"
    //
    // MMcG: 22-Nov-2019 - Unfortunately this field has now been overloaded so that it can contain either the above style
    // query params or, as of KeePassXC 2.5 (ish) it can contain an OTPAUTH URL...
    // We need to check which it is here... we also need to remember the style used so we don't break KeeOTP users :(
    
    StringValue* keeOtpSecretEntry = fields[kKeeOtpPluginKey];
    
    if(keeOtpSecretEntry) {
        // New KeePassXC Style... URL in the OTP Field - Ideally everyone should use this...
        
        NSURL *url = [NSURL URLWithString:keeOtpSecretEntry.value];
        OTPToken* t = [NodeFields getOtpTokenFromUrl:url];
        if(t) {
            *usingLegacyKeeOtpStyle = NO;
            return t;
        }

        // Old KeeOTP Plugin Style...
        
        NSString* keeOtpSecret = keeOtpSecretEntry.value;
        if(keeOtpSecret) {
            NSDictionary *params = [NodeFields getQueryParams:keeOtpSecret];
            NSString* secret = params[@"key"];
            
            if(secret.length) {
                *usingLegacyKeeOtpStyle = YES; // We need to keep this crappy state around so we can save in legacy style if necessary... :(
                
                // KeeOTP sometimes URL escapes '+' in this base32 encoded string, check for that and decode
                
                if([secret containsString:@"%3d"]) {
                    secret = [secret stringByRemovingPercentEncoding];
                }
                
                OTPToken* token = [OTPToken tokenWithType:OTPTokenTypeTimer secret:[NSData secretWithString:secret] name:@"<Unknown>" issuer:@"<Unknown>"];
                
                if(params[@"step"]) {
                    token.period = [params[@"step"] integerValue];
                }
                
                if(params[@"size"]) {
                    token.digits = [params[@"size"] integerValue];
                }
                
                if([token validate]) {
                    return token;
                }
            }
            
            // Could just be a raw token in here...
            // Examples from a user on Github:
            //            otp: ZOFHRYXNSJDUGHSJ
            //
            //            otp: ZOFH RYXN SJDU GHSJ
            //
            //            otp: zofhryxnsjdughsj
            //
            //            otp: zofh ryxn sjdu ghsj

            OTPToken* token = [OTPToken tokenWithType:OTPTokenTypeTimer
                                               secret:[NSData secretWithString:keeOtpSecret]
                                                 name:@"<Unknown>" issuer:@"<Unknown>"];

            if([token validate]) {
                return token;
            }
        }
    }
    
    return nil;
}

+ (NSURL*)findOtpUrlInString:(NSString*)notes {
    if(!notes.length) {
        return nil;
    }
    
    NSError* error;
    NSDataDetector* detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:&error];
    
    if(detector) {
        NSArray *matches = [detector matchesInString:notes
                                             options:0
                                               range:NSMakeRange(0, [notes length])];
        for (NSTextCheckingResult *match in matches) {
            if ([match resultType] == NSTextCheckingTypeLink) {
                NSURL *url = [match URL];
                if(url && url.scheme && [url.scheme isEqualToString:kOtpAuthScheme]) {
                    OTPToken* ret = [OTPToken tokenWithURL:url];
                    if(ret) {
                        return url;
                    }
                }
            }
        }
    }
    else {
        NSLog(@"Error creating data detector: %@", error);
    }
    
    return nil;
}

//

- (BOOL)expired {
    return self.expires != nil && [NSDate.date compare:self.expires] == NSOrderedDescending;
}

- (BOOL)nearlyExpired {
    if(self.expires == nil || self.expired) {
        return NO;
    }
    
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *components = [gregorian components:NSCalendarUnitDay
                                                fromDate:[NSDate date]
                                                  toDate:self.expires
                                                 options:0];
    
    NSInteger days = [components day];

    return days < 14;
}

- (NSArray<NSString *> *)alternativeUrls {
    NSDictionary<NSString*, StringValue*> *filtered = [self.mutableCustomFields filter:^BOOL(NSString * _Nonnull key, StringValue * _Nonnull value) {
        return [key hasPrefix:@"KP2A_URL"] || [key hasPrefix:@"URL"];
    }];
    
    NSArray<NSString*>* values = [filtered map:^id _Nonnull(NSString * _Nonnull key, StringValue * _Nonnull value) {
        return value.value;
    }];
    
    return [values sortedArrayUsingComparator:finderStringComparator];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"{ username = [%@]\n    email = [%@]\n    url = [%@]\n}",
            self.username,
            self.email,
            self.url];
}

@end
