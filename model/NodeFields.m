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
#import "NSDate+Extensions.h"

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
        self.customData = [[MutableOrderedDictionary alloc] init];
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

- (MutableOrderedDictionary<NSString*, NSString*>*)cloneCustomData {
    MutableOrderedDictionary<NSString*, NSString*>* ret = [[MutableOrderedDictionary alloc] init];
    
    for (NSString* key in self.customData.allKeys) {
        NSString* value = self.customData[key];
        ret[key] = value;
    }
    
    return ret;
}

- (BOOL)isSyncEqualTo:(NodeFields *)other params:(SyncComparisonParams *)params {
    BOOL simpleEqual =  [self.username compare:other.username] == NSOrderedSame &&
                        [self.password compare:other.password] == NSOrderedSame &&
                        [self.url compare:other.url] == NSOrderedSame &&
                        [self.notes compare:other.notes] == NSOrderedSame &&
                        [self.email compare:other.email] == NSOrderedSame;

    if ( !simpleEqual ) return NO;
    
    
    
    if(self.customFields.count != other.customFields.count) {
        return YES;
    }

    for (NSString* key in self.customFields.allKeys) {
        StringValue* a = self.customFields[key];
        StringValue* b = other.customFields[key];
        
        if(![a isEqual:b]) {
            return NO;
        }
    }

    
    
    if(self.attachments.count != other.attachments.count) {
        return NO;
    }
    
    
    
    for (int i=0; i < self.attachments.count; i++) {
        NodeFileAttachment* myAttachment = self.attachments[i];
        NodeFileAttachment* theirAttachment = other.attachments[i];
        
        [self attachmentIsSyncEqualTo:myAttachment b:theirAttachment params:params];
    }

    
    
    if ( ![self.created isEqualToDate:other.created] ) return NO;
    if ( ![self.modified isEqualToDate:other.modified] ) return NO;
    if ( ![self.expires isEqualToDate:other.expires] ) return NO;
        
    if ((self.foregroundColor == nil && other.foregroundColor != nil) || (self.foregroundColor != nil && ![self.foregroundColor isEqual:other.foregroundColor] )) {
        return NO;
    }
    if ((self.backgroundColor == nil && other.backgroundColor != nil) || (self.backgroundColor != nil && ![self.backgroundColor isEqual:other.backgroundColor] )) {
        return NO;
    }
    if ((self.overrideURL == nil && other.overrideURL != nil) || (self.overrideURL != nil && ![self.overrideURL isEqual:other.overrideURL] )) {
        return NO;
    }
    if ((self.autoType == nil && other.autoType != nil) || (self.autoType != nil && ![self.autoType isEqual:other.autoType])) {
        return NO;
    }
    
    

    if ( ![self.tags isEqualToSet:other.tags]) return NO; 

    if ( ![self.customData isEqual:other.customData] ) return NO; 

    return NO;
}

- (BOOL)attachmentIsSyncEqualTo:(NodeFileAttachment*)a b:(NodeFileAttachment*)b params:(SyncComparisonParams *)params {
    return params.compareNodeAttachmentBlock(a, b); 
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
    NSArray<NSDictionary*>* customData = dict[@"customData"];
    NSString* defaultAutoTypeSequence = dict[@"defaultAutoTypeSequence"];
    NSNumber* enableAutoType = dict[@"enableAutoType"];
    NSNumber* enableSearching = dict[@"enableSearching"];
    NSString* lastTopVisibleEntry = dict[@"lastTopVisibleEntry"];
    NSArray<NSString*>* tagsArray = dict[@"tags"]; 
    NSString* foregroundColor = dict[@"foregroundColor"];
    NSString* backgroundColor = dict[@"backgroundColor"];
    NSString* overrideURL = dict[@"overrideURL"];
    NSNumber* autoTypeEnabled = dict[@"autoTypeEnabled"];
    NSNumber* autoTypeDataTransferObfuscation = dict[@"autoTypeDataTransferObfuscation"];
    NSString* autoTypeDefaultSequence = dict[@"autoTypeDefaultSequence"];
    NSArray<NSDictionary*>* autoTypeAssoc = dict[@"autoTypeAssoc"];
    
    NodeFields* ret = [[NodeFields alloc] initWithUsername:username
                                                       url:url
                                                  password:password
                                                     notes:notes
                                                     email:email];

    ret.tags = [NSMutableSet setWithArray:tagsArray];
    
    ret.passwordModified = passwordModified != nil ? [NSDate dateWithTimeIntervalSince1970:passwordModified.unsignedIntegerValue] : nil;
    ret.expires = expires != nil ? [NSDate dateWithTimeIntervalSince1970:expires.unsignedIntegerValue] : nil;
    
    
    
    NSArray<NodeFileAttachment*>* nfas = [attachments map:^id _Nonnull(NSDictionary * _Nonnull obj, NSUInteger idx) {
        NSString* filename = obj.allKeys.firstObject;
        NSNumber* index = obj[filename];
        
        return [NodeFileAttachment attachmentWithName:filename index:index.unsignedIntValue linkedObject:nil];
    }];
    [ret.attachments addObjectsFromArray:nfas];
    
    
    
    for (NSDictionary* obj in customFields) {
        NSString* key = obj[@"key"];
        NSString* value = obj[@"value"];
        NSNumber* protected = obj[@"protected"];
        [ret setCustomField:key value:[StringValue valueWithString:value protected:protected.boolValue]];
    }
    
    
    
    for (NSDictionary* obj in customData) {
        NSString* key = obj[@"key"];
        NSString* value = obj[@"value"];
        ret.customData[key] = value;
    }
    
    ret.defaultAutoTypeSequence = defaultAutoTypeSequence; 
    ret.enableAutoType = enableAutoType; 
    ret.enableSearching = enableSearching; 
    ret.lastTopVisibleEntry = lastTopVisibleEntry ? [[NSUUID alloc] initWithUUIDString:lastTopVisibleEntry] : nil; 
    
    
    
    ret.foregroundColor = foregroundColor;
    ret.backgroundColor = backgroundColor;
    ret.overrideURL = overrideURL;

    if (autoTypeEnabled != nil) {
        ret.autoType = [[AutoType alloc] init];
        ret.autoType.enabled = autoTypeEnabled.boolValue;
        ret.autoType.dataTransferObfuscation = autoTypeDataTransferObfuscation == nil ? NO : autoTypeDataTransferObfuscation.boolValue;
        ret.autoType.defaultSequence = autoTypeDefaultSequence;

        if (autoTypeAssoc) {
            NSMutableArray *ma = NSMutableArray.array;
            
            for (NSDictionary* obj in autoTypeAssoc) {
                AutoTypeAssociation* ata = [[AutoTypeAssociation alloc] init];
                ata.window = obj[@"window"];
                ata.keystrokeSequence = obj[@"keystrokeSequence"];
                [ma addObject:ata];
            }
            ret.autoType.asssociations = ma.copy;
        }
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
    
    
    
    NSArray<NSDictionary*>* customData = [self.customData.allKeys map:^id _Nonnull(NSString * _Nonnull key, NSUInteger idx) {
        NSString* value = self.customData[key];
        return @{ @"key" : key, @"value" : value };
    }];
    ret[@"customData"] = customData;
  
    if (self.defaultAutoTypeSequence) {
        ret[@"defaultAutoTypeSequence"] = self.defaultAutoTypeSequence;
    }
    if (self.enableAutoType != nil) {
        ret[@"enableAutoType"] = self.enableAutoType;
    }
    if (self.enableSearching != nil) {
        ret[@"enableSearching"] = self.enableSearching;
    }
    if (self.defaultAutoTypeSequence) {
        ret[@"lastTopVisibleEntry"] = self.lastTopVisibleEntry.UUIDString;
    }
    if (self.foregroundColor) {
        ret[@"foregroundColor"] = self.foregroundColor;
    }
    if (self.backgroundColor) {
        ret[@"backgroundColor"] = self.backgroundColor;
    }
    if (self.overrideURL) {
        ret[@"overrideURL"] = self.overrideURL;
    }

    if (self.autoType) {
        ret[@"autoTypeEnabled"] = @(self.autoType.enabled);
        ret[@"autoTypeDataTransferObfuscation"] = @(self.autoType.dataTransferObfuscation);
        
        if (self.autoType.defaultSequence) {
            ret[@"autoTypeDefaultSequence"] = self.autoType.defaultSequence;
        }
        
        NSArray<NSDictionary*>* autoTypeAssoc = [self.autoType.asssociations map:^id _Nonnull(AutoTypeAssociation * _Nonnull obj, NSUInteger idx) {
            return @{ @"window" : obj.window, @"keystrokeSequence" : obj.keystrokeSequence };
        }];
        ret[@"autoTypeAssoc"] = autoTypeAssoc;
    }
    
    
    
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
    ret.defaultAutoTypeSequence = self.defaultAutoTypeSequence;
    ret.enableSearching = self.enableSearching;
    ret.enableAutoType = self.enableAutoType;
    ret.lastTopVisibleEntry = self.lastTopVisibleEntry;
    ret.tags = self.tags.mutableCopy;
    ret.foregroundColor = self.foregroundColor;
    ret.backgroundColor = self.backgroundColor;
    ret.overrideURL = self.overrideURL;
    ret.attachments = [self cloneAttachments];
    ret.mutableCustomFields = [self cloneCustomFields];
    ret.customData = [self cloneCustomData];
    
    if (self.autoType) {
        ret.autoType = [[AutoType alloc] init];
        ret.autoType.enabled = self.autoType.enabled;
        ret.autoType.dataTransferObfuscation = self.autoType.dataTransferObfuscation;
        ret.autoType.defaultSequence = self.autoType.defaultSequence;
        
        ret.autoType.asssociations = self.autoType.asssociations;
        
        if (self.autoType.asssociations) {
            NSMutableArray *ma = NSMutableArray.array;
            
            for (AutoTypeAssociation* assoc in self.autoType.asssociations) {
                AutoTypeAssociation* ata = [[AutoTypeAssociation alloc] init];
                ata.window = assoc.window;
                ata.keystrokeSequence = assoc.keystrokeSequence;
                [ma addObject:ata];
            }
            
            ret.autoType.asssociations = ma.copy;
        }

    }

    if (clearHistory) {
        ret.keePassHistory = [NSMutableArray array];
    }
    else {
        ret.keePassHistory = self.keePassHistory.mutableCopy;
    }

    if (cloneMetadataDates) {
        [ret setTouchPropertiesWithCreated:self.created
                                  accessed:self.accessed
                                  modified:self.modified
                           locationChanged:self.locationChanged
                                usageCount:self.usageCount];
    }

    return ret;
}

- (void)setPassword:(NSString *)password {
    NSString* newPassword = password;
    NSString* oldPassword = _password;
    
    if([newPassword compare:oldPassword] == NSOrderedSame) {
        return;
    }
    
    _password = newPassword;
    
    
    
    self.passwordModified = [NSDate date];
    
    
    
    PasswordHistory *pwHistory = self.passwordHistory;
    if (pwHistory.enabled && pwHistory.maximumSize > 0 && newPassword) {
        [pwHistory.entries addObject:[[PasswordHistoryEntry alloc] initWithPassword:oldPassword]];
        
        if ((pwHistory.entries).count > pwHistory.maximumSize) {
            NSUInteger count = (pwHistory.entries).count;
            NSArray *slice = [pwHistory.entries subarrayWithRange:(NSRange) {count - pwHistory.maximumSize, pwHistory.maximumSize }];
            [pwHistory.entries removeAllObjects];
            [pwHistory.entries addObjectsFromArray:slice];
        }
    }
    
    self.hasCachedOtpToken = NO; 
}

- (void)setNotes:(NSString *)notes {
    if([notes compare:_notes] == NSOrderedSame) {
        return;
    }
    
    _notes = notes;
    self.hasCachedOtpToken = NO; 
}

- (NSDictionary<NSString *,StringValue *> *)customFields {
    return [self.mutableCustomFields copy];
}

- (void)setCustomFields:(NSDictionary<NSString *,StringValue *> *)customFields {
    self.mutableCustomFields = [customFields mutableCopy];
    self.hasCachedOtpToken = NO; 
}

- (void)removeAllCustomFields {
    [self.mutableCustomFields removeAllObjects];
    self.hasCachedOtpToken = NO; 
}

- (void)removeCustomField:(NSString*)key {
    [self.mutableCustomFields removeObjectForKey:key];
    self.hasCachedOtpToken = NO; 
}

- (void)setCustomField:(NSString*)key value:(StringValue*)value {
    self.mutableCustomFields[key] = value;
    self.hasCachedOtpToken = NO; 
}

- (void)touch:(BOOL)modified {
    [self touch:modified date:NSDate.date];
}

- (void)touch:(BOOL)modified date:(NSDate *)date {
    _usageCount = self.usageCount != nil ? @(self.usageCount.integerValue + 1) : @(1);

    _accessed = date;
    
    if(modified) {
        [self setModifiedDateExplicit:date];
    }
}

- (void)touchLocationChanged {
    [self touchLocationChanged:NSDate.date];
}

- (void)touchLocationChanged:(NSDate *)date {
    [self setTouchPropertiesWithCreated:nil accessed:nil modified:nil locationChanged:date usageCount:nil];
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
    
    
    if(appendUrlToNotes) {
        self.notes = [self.notes stringByAppendingFormat:@"\n-----------------------------------------\nStrongbox TOTP Auth URL: [%@]", [token url:YES]];
    }
    else {
        
        
        
        self.mutableCustomFields[kKeePassXcTotpSeedKey] = [StringValue valueWithString:[token.secret mmcg_base32String] protected:YES];
        
        if(token.algorithm == OTPAlgorithmSteam) {
            NSString* valueString = [NSString stringWithFormat:@"%lu;S", (unsigned long)token.period];
            self.mutableCustomFields[kKeePassXcTotpSettingsKey] = [StringValue valueWithString:valueString protected:YES];
        }
        else {
            NSString* valueString = [NSString stringWithFormat:@"%lu;%lu", (unsigned long)token.period, (unsigned long)token.digits];
            self.mutableCustomFields[kKeePassXcTotpSettingsKey] = [StringValue valueWithString:valueString protected:YES];
        }
        
        
        
        
        
        
        
        
        
        if(self.usingLegacyKeeOtpStyle) {
            NSURLComponents *components = [NSURLComponents componentsWithString:@"http:
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
    
    self.hasCachedOtpToken = NO; 
}

- (void)clearTotp {
    
    
    
    
    self.mutableCustomFields[kKeePassXcTotpSeedKey] = nil;
    self.mutableCustomFields[kKeePassXcTotpSettingsKey] = nil;
    
    
    
    
    self.mutableCustomFields[kKeeOtpPluginKey] = nil;
    
    
    
    NSTextCheckingResult *result = [[NodeFields totpNotesRegex] firstMatchInString:self.notes options:kNilOptions range:NSMakeRange(0, self.notes.length)];
    
    if(result) {
        NSLog(@"Found matching OTP in Notes: [%@]", [self.notes substringWithRange:result.range]);
        self.notes = [self.notes stringByReplacingCharactersInRange:result.range withString:@""];
    }
    
    self.hasCachedOtpToken = NO; 
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
    
    
    
    
    NSURL *otpUrl = [NSURL URLWithString:password];
    OTPToken* ret = [NodeFields getOtpTokenFromUrl:otpUrl];
    if(ret) {
        return ret;
    }

    
    
    ret = [NodeFields getKeeOtpAndNewKeePassXCToken:fields usingLegacyKeeOtpStyle:usingLegacyKeeOtpStyle];
    if(ret) {
        return ret;
    }

    
    
    ret = [NodeFields getKeePassXCLegacyOTPToken:fields];
    if(ret) {
        return ret;
    }

    
    
    NSURL *url = [NodeFields findOtpUrlInString:notes];
    
    return [NodeFields getOtpTokenFromUrl:url];
}

+ (OTPToken*)getKeePassXCLegacyOTPToken:(NSDictionary<NSString*, StringValue*>*)fields {
    
    
    
    
    
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
                        if(![params[1] isEqualToString:@"S"]) { 
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
    
    
    
    
    
    
    
    
    StringValue* keeOtpSecretEntry = fields[kKeeOtpPluginKey];
    
    if(keeOtpSecretEntry) {
        
        
        NSURL *url = [NSURL URLWithString:keeOtpSecretEntry.value];
        OTPToken* t = [NodeFields getOtpTokenFromUrl:url];
        if(t) {
            *usingLegacyKeeOtpStyle = NO;
            return t;
        }

        
        
        NSString* keeOtpSecret = keeOtpSecretEntry.value;
        if(keeOtpSecret) {
            NSDictionary *params = [NodeFields getQueryParams:keeOtpSecret];
            NSString* secret = params[@"key"];
            
            if(secret.length) {
                *usingLegacyKeeOtpStyle = YES; 
                
                
                
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
