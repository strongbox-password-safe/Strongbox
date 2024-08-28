//
//  NodeFields.m
//  MacBox
//
//  Created by Mark on 31/08/2017.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
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
#import "Node.h"
#import "NSString+Extensions.h"
#import "Constants.h"
#import "KeePassConstants.h"

NSString* const kOtpAuthScheme = @"otpauth";

@interface NodeFields ()

@property BOOL hasCachedOtpToken;
@property OTPToken* cachedOtpToken;
@property MutableOrderedDictionary<NSString*, StringValue*> *mutableCustomFields;
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
    return [Constants.TotpCustomFieldKeys containsObject:key];
}

+ (BOOL)isPasskeyCustomFieldKey:(NSString*)key {
    return [Constants.PasskeyCustomFieldKeys containsObject:key];
}

+ (BOOL)isAlternativeURLCustomFieldKey:(NSString*)key {
    return [key hasPrefix:@"KP2A_URL"] || [key hasPrefix:@"URL"];
}



- (instancetype)init {
    return [self initWithUsername:@""
                              url:@""
                         password:@""
                            notes:@""
                            email:@""];
}

- (instancetype)initWithUsername:(NSString*_Nonnull)username
                                       url:(NSString*_Nonnull)url
                                  password:(NSString*_Nonnull)password
                                     notes:(NSString*_Nonnull)notes
                                     email:(NSString*_Nonnull)email {
    if (self = [super init]) {
        self.username = username == nil ? @"" : username;
        self.url = url == nil ? @"" : url;
        self.password = password == nil ? @"" : password;
        self.notes = notes == nil ? @"" : notes;

        self.passwordHistory = [[PasswordHistory alloc] init];
        
        NSDate* date = [NSDate date];
        
        _modified = date;
        _accessed = date;
        _locationChanged = date;
        _usageCount = @(0);
        _created = date;
        
        self.passwordModified = date;
        self.attachments = [NSMutableDictionary dictionary];
        self.mutableCustomFields = [[MutableOrderedDictionary alloc] init];
        self.keePassHistory = [NSMutableArray array];
        self.tags = [NSMutableSet set];
        self.customData = @{}.mutableCopy;
        self.qualityCheck = YES;
        self.isExpanded = YES; 
        
        self.email = email == nil ? @"" : email;
    }
    
    return self;
}

- (AutoType*)cloneAutoType {
    if (self.autoType) {
        AutoType *autoType = [[AutoType alloc] init];
        autoType.enabled = self.autoType.enabled;
        autoType.dataTransferObfuscation = self.autoType.dataTransferObfuscation;
        autoType.defaultSequence = self.autoType.defaultSequence;
        
        autoType.asssociations = self.autoType.asssociations;
        
        if (self.autoType.asssociations) {
            NSMutableArray *ma = NSMutableArray.array;
            
            for (AutoTypeAssociation* assoc in self.autoType.asssociations) {
                AutoTypeAssociation* ata = [[AutoTypeAssociation alloc] init];
                ata.window = assoc.window;
                ata.keystrokeSequence = assoc.keystrokeSequence;
                [ma addObject:ata];
            }
            
            autoType.asssociations = ma.copy;
        }
        
        return autoType;
    }
    
    return nil;
}

- (MutableOrderedDictionary<NSString*, StringValue*>*)cloneCustomFields {
    MutableOrderedDictionary<NSString*, StringValue*>* ret = [[MutableOrderedDictionary alloc] init];
    
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
    NSDictionary<NSString*, NSString*>* attachments = dict[@"attachments"];
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
    NSNumber* ie = ((NSNumber*)dict[@"isExpanded"]);
    NSNumber* qc = ((NSNumber*)dict[@"qualityCheck"]);
    NSString* ppg = dict[@"previousParentGroup"];
    
    NSNumber* created = dict[@"created"];
    NSNumber* modified = dict[@"modified"];
    NSNumber* accessed = dict[@"accessed"];
    NSNumber* locationChanged = dict[@"locationChanged"];
    NSNumber* usageCount = dict[@"usageCount"];
    
    NodeFields* ret = [[NodeFields alloc] initWithUsername:username
                                                       url:url
                                                  password:password
                                                     notes:notes
                                                     email:email];

    ret.tags = [NSMutableSet setWithArray:tagsArray];
    
    ret.passwordModified = passwordModified != nil ? [NSDate dateWithTimeIntervalSince1970:passwordModified.unsignedIntegerValue] : nil;
    ret.expires = expires != nil ? [NSDate dateWithTimeIntervalSince1970:expires.unsignedIntegerValue] : nil;
    ret.previousParentGroup = ppg ? [[NSUUID alloc] initWithUUIDString:ppg] : nil;
    
    
    
    for (NSString* filename in attachments.allKeys) {
        NSString* base64 = attachments[filename];
        NSData* data = [[NSData alloc] initWithBase64EncodedString:base64 options:kNilOptions];
        KeePassAttachmentAbstractionLayer* dbAttachment = [[KeePassAttachmentAbstractionLayer alloc] initNonPerformantWithData:data compressed:YES protectedInMemory:YES];
        ret.attachments[filename] = dbAttachment;
    }
    
    
    
    for (NSDictionary* obj in customFields) {
        NSString* key = obj[@"key"];
        NSString* value = obj[@"value"];
        NSNumber* protected = obj[@"protected"];
        [ret setCustomField:key value:[StringValue valueWithString:value protected:protected.boolValue]];
    }
    
    
    
    for (NSDictionary* obj in customData) {
        NSString* key = obj[@"key"];
        NSString* value = obj[@"value"];
        NSNumber* modNum = obj[@"modified"];
        NSDate* modified = modNum != nil ? [NSDate dateWithTimeIntervalSince1970:modNum.unsignedIntegerValue] : nil;
        ret.customData[key] = [ValueWithModDate value:value modified:modified];
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
        ret.autoType.dataTransferObfuscation = autoTypeDataTransferObfuscation == nil ? 0 : autoTypeDataTransferObfuscation.integerValue;
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

    
    
    ret.isExpanded = ie != nil ? ie.boolValue : NO;
    ret.qualityCheck = qc != nil ? qc.boolValue : YES;
    
    
    
    NSDate* cDate = created != nil ? [NSDate dateWithTimeIntervalSince1970:created.unsignedIntegerValue] : nil;
    NSDate* aDate = accessed != nil ? [NSDate dateWithTimeIntervalSince1970:accessed.unsignedIntegerValue] : nil;
    NSDate* mDate = modified != nil ? [NSDate dateWithTimeIntervalSince1970:modified.unsignedIntegerValue] : nil;
    NSDate* lcDate = locationChanged != nil ? [NSDate dateWithTimeIntervalSince1970:locationChanged.unsignedIntegerValue] : nil;
    
    [ret setTouchPropertiesWithCreated:cDate accessed:aDate modified:mDate locationChanged:lcDate usageCount:usageCount];
    
    return ret;
}

- (NSDictionary *)serialize:(SerializationPackage *)serialization {
    NSMutableDictionary* ret = [NSMutableDictionary dictionary];
    
    ret[@"username"] = self.username;
    ret[@"url"] = self.url;
    ret[@"password"] = self.password;
    ret[@"notes"] = self.notes;
    
    if(self.passwordModified) {
        ret[@"passwordModified"] = @((NSUInteger)[self.passwordModified timeIntervalSince1970]);
    }
    if(self.expires) {
        ret[@"expires"] = @((NSUInteger)[self.expires timeIntervalSince1970]);
    }

    
    
    NSMutableDictionary<NSString*, NSString*> *attachments = NSMutableDictionary.dictionary;
    
    for (NSString* filename in self.attachments.allKeys) {
        KeePassAttachmentAbstractionLayer* dbAttachment = self.attachments[filename];
        NSData* data = dbAttachment.nonPerformantFullData;
        NSString* base64 = [data base64EncodedStringWithOptions:kNilOptions];
        attachments[filename] = base64;
    }
    ret[@"attachments"] = attachments;
    
    
    
    NSArray<NSDictionary*>* customFields = [self.customFields.allKeys map:^id _Nonnull(NSString * _Nonnull key, NSUInteger idx) {
        StringValue* value = self.customFields[key];
        return @{ @"key" : key, @"value" : value.value, @"protected" : @(value.protected) };
    }];
    ret[@"customFields"] = customFields;
    
    
    
    NSArray<NSDictionary*>* customData = [self.customData.allKeys map:^id _Nonnull(NSString * _Nonnull key, NSUInteger idx) {
        ValueWithModDate* vm = self.customData[key];
        
        if ( vm.modified ) {
            return @{ @"key" : key, @"value" : vm.value, @"modified" : @((NSUInteger)[vm.modified timeIntervalSince1970]) };
        }
        else {
            return @{ @"key" : key, @"value" : vm.value };
        }
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
    if (self.previousParentGroup) {
        ret[@"previousParentGroup"] = self.previousParentGroup.UUIDString;
    }
    
    ret [@"isExpanded"] = @(self.isExpanded);
    ret [@"qualityCheck"] = @(self.qualityCheck);
    
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
    
    

    if ( self.created ) {
        ret[@"created"] = @((NSUInteger)[self.created timeIntervalSince1970]);
    }
    if ( self.modified ) {
        ret[@"modified"] = @((NSUInteger)[self.modified timeIntervalSince1970]);
    }
    if ( self.accessed ) {
        ret[@"accessed"] = @((NSUInteger)[self.accessed timeIntervalSince1970]);
    }
    if ( self.locationChanged ) {
        ret[@"locationChanged"] = @((NSUInteger)[self.locationChanged timeIntervalSince1970]);
    }
    if ( self.usageCount ) {
        ret[@"usageCount"] = self.usageCount;
    }

    return ret;
}



- (BOOL)isSyncEqualTo:(NodeFields *)other isForUIDiffReport:(BOOL)isForUIDiffReport checkHistory:(BOOL)checkHistory {
    BOOL simpleEqual =  [self.username compare:other.username] == NSOrderedSame &&
                        [self.password compare:other.password] == NSOrderedSame &&
                        [self.url compare:other.url] == NSOrderedSame &&
                        [self.notes compare:other.notes] == NSOrderedSame;

    if ( !simpleEqual ) return NO;
    
    
    
    if ( ![self.customFields isEqual:other.customFields] ) {
        return NO;
    }

    
    
    if ( ![self.attachments isEqualToDictionary:other.attachments] ) {
        return NO;
    }
 
    
    
    if ((self.created == nil && other.created != nil) || (self.created != nil && ![self.created isEqualToDate:other.created] )) return NO;

    if (!isForUIDiffReport) {
        
        
        if ((self.modified == nil && other.modified != nil) || (self.modified != nil && ![self.modified isEqualToDate:other.modified] )) return NO;
    }
    
    if ((self.expires == nil && other.expires != nil) || (self.expires != nil && ![self.expires isEqualToDate:other.expires] )) return NO;
            
    if ((self.foregroundColor.length == 0 && other.foregroundColor.length) || (self.foregroundColor.length && ![self.foregroundColor isEqualToString:other.foregroundColor] )) {
        return NO;
    }
    if ((self.backgroundColor.length == 0 && other.backgroundColor.length) || (self.backgroundColor.length && ![self.backgroundColor isEqualToString:other.backgroundColor] )) {
        return NO;
    }
    if ((self.overrideURL.length == 0 && other.overrideURL.length) || (self.overrideURL.length && ![self.overrideURL isEqualToString:other.overrideURL] )) {
        return NO;
    }
    
    if ( ![AutoType isDefault:self.autoType] || ![AutoType isDefault:other.autoType]) {
        if ((self.autoType == nil && other.autoType != nil) || (self.autoType != nil && ![self.autoType isEqual:other.autoType])) {
            return NO;
        }
    }
    
    

    if ( ![self.tags isEqualToSet:other.tags]) return NO;

    if ( ![self.customData isEqualToDictionary:other.customData] ) return NO; 

    
    
    if (checkHistory) {
        if (self.keePassHistory.count == other.keePassHistory.count) {
            for (int i=0; i<self.keePassHistory.count; i++) {
                Node* myHist = self.keePassHistory[i];
                Node* otherHist = other.keePassHistory[i];
                if (![myHist isSyncEqualTo:otherHist isForUIDiffReport:YES checkHistory:NO]) {
                    return NO;
                }
            }
        }
        else {
            return NO;
        }
    }
    
    
    
    
    
    
    
    if ( self.qualityCheck != other.qualityCheck ) {
        return NO;
    }

    

    if ((self.previousParentGroup == nil && other.previousParentGroup != nil) || (self.previousParentGroup != nil && ![self.previousParentGroup isEqual:other.previousParentGroup])) {
        return NO;
    }
    
    return YES;
}

- (void)mergePropertiesInFromNode:(NodeFields *)mergeNodeFields mergeLocationChangedDate:(BOOL)mergeLocationChangedDate includeHistory:(BOOL)includeHistory {
    [self copyFieldsFrom:mergeNodeFields copyTouchDates:YES copyLocationChangedDate:mergeLocationChangedDate includeHistory:includeHistory];
}

- (void)restoreFromHistoricalNode:(NodeFields *)historicalFields {
    [self copyFieldsFrom:historicalFields copyTouchDates:NO copyLocationChangedDate:NO includeHistory:NO];
}

- (void)copyFieldsFrom:(NodeFields *)from copyTouchDates:(BOOL)copyTouchDates copyLocationChangedDate:(BOOL)copyLocationChangedDate includeHistory:(BOOL)includeHistory {
    [NodeFields copyField:from to:self copyTouchDates:copyTouchDates copyLocationChangedDate:copyLocationChangedDate includeHistory:includeHistory];
}

- (NodeFields*)cloneOrDuplicate:(BOOL)cloneMetadataDates {
    NodeFields* ret = [[NodeFields alloc] init];

    [NodeFields copyField:self to:ret copyTouchDates:cloneMetadataDates copyLocationChangedDate:YES includeHistory:YES];

    return ret;
}

+ (void)copyField:(NodeFields*)from to:(NodeFields*)to copyTouchDates:(BOOL)copyTouchDates copyLocationChangedDate:(BOOL)copyLocationChangedDate includeHistory:(BOOL)includeHistory {
    to.username = from.username;
    to.url = from.url;
    to.password = from.password;
    to.notes = from.notes;
    
    to.customFields = [from cloneCustomFields];
    
    to.expires = from.expires;
    to.defaultAutoTypeSequence = from.defaultAutoTypeSequence;
    to.enableAutoType = from.enableAutoType;
    to.enableSearching = from.enableSearching;
    to.lastTopVisibleEntry = from.lastTopVisibleEntry;
    to.foregroundColor = from.foregroundColor;
    to.backgroundColor = from.backgroundColor;
    to.overrideURL = from.overrideURL;
    to.passwordModified = from.passwordModified;
    to.autoType = [from cloneAutoType];
    to.tags = from.tags.mutableCopy;
    to.customData = from.customData.mutableCopy;
    to.attachments = from.attachments.mutableCopy;
    to.isExpanded = from.isExpanded;
    to.qualityCheck = from.qualityCheck;
    to.previousParentGroup = from.previousParentGroup;
    
    if (copyTouchDates) {
        [to setTouchPropertiesWithCreated:from.created
                                 accessed:from.accessed
                                 modified:from.modified
                          locationChanged:copyLocationChangedDate ? from.locationChanged : nil
                               usageCount:from.usageCount];
    }

    if(includeHistory) {
        to.keePassHistory = from.keePassHistory.mutableCopy;
        to.passwordHistory = [from.passwordHistory clone];
    }
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

- (MutableOrderedDictionary<NSString *,StringValue *> *)customFieldsNoEmail {
    MutableOrderedDictionary* ret = [self.mutableCustomFields clone];
    
    [ret removeObjectForKey:kCanonicalEmailFieldName];
    
    return [ret copy];
}

- (MutableOrderedDictionary<NSString *,StringValue *> *)customFieldsFiltered {
    MutableOrderedDictionary* copy = [self.mutableCustomFields clone];
    MutableOrderedDictionary* ret = [[MutableOrderedDictionary alloc] init];
    
    for (NSString* key in copy.keys ) {
        if ( ![NodeFields isTotpCustomFieldKey:key] && ![NodeFields isPasskeyCustomFieldKey:key] && ![key isEqualToString:kCanonicalEmailFieldName]) {
            [ret addKey:key andValue:copy[key]];
        }
    }
    
    return [ret copy];
}

- (MutableOrderedDictionary<NSString *,StringValue *> *)customFields {
    return [self.mutableCustomFields clone];
}

- (void)setCustomFields:(MutableOrderedDictionary<NSString*, StringValue*>*)customFields {
    self.mutableCustomFields = [customFields clone];
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

+ (OTPToken *)getOtpTokenFromString:(NSString *)string forceSteam:(BOOL)forceSteam {
    return [NodeFields getOtpTokenFromString:string forceSteam:forceSteam issuer:nil username:nil];
}

+ (OTPToken*)getOtpTokenFromString:(NSString * _Nonnull)string
                        forceSteam:(BOOL)forceSteam
                            issuer:(NSString*_Nullable)issuer
                          username:(NSString*_Nullable)username {
    OTPToken *token = nil;
    NSURL *url = [NodeFields findOtpUrlInString:string];
    
    if ( url ) {
        token = [NodeFields getOtpTokenFromUrl:url];
    }
    else {
        NSURL* sanityCheck = [NSURL URLWithString:string];
        if ( sanityCheck && sanityCheck.scheme.length ) {
            
            
            
            return nil;
        }
        
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

- (void)setLegacyTotpFields:(NSString *)base32Secret token:(OTPToken * _Nonnull)token {
    self.mutableCustomFields[kKeePassXcTotpSeedKey] = [StringValue valueWithString:base32Secret protected:YES];
    
    if ( token.algorithm == OTPAlgorithmSteam ) {
        NSString* valueString = [NSString stringWithFormat:@"%lu;S", (unsigned long)token.period];
        self.mutableCustomFields[kKeePassXcTotpSettingsKey] = [StringValue valueWithString:valueString protected:YES];
    }
    else {
        NSString* valueString = [NSString stringWithFormat:@"%lu;%lu", (unsigned long)token.period, (unsigned long)token.digits];
        self.mutableCustomFields[kKeePassXcTotpSettingsKey] = [StringValue valueWithString:valueString protected:YES];
    }
    
    
    
    
    
    
    
    
    
    if ( self.usingLegacyKeeOtpStyle ) {
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
}

- (void)setWindowsKeePassTotpFields:(NSString *)base32Secret token:(OTPToken * _Nonnull)token {
    if ( token.algorithm != OTPAlgorithmSteam && token.algorithm != OTPAlgorithmYandex ) {
        self.mutableCustomFields[kOriginalWindowsSecretBase32Key] = [StringValue valueWithString:base32Secret protected:YES];
        
        if(token.period != OTPToken.defaultPeriod) {
            self.mutableCustomFields[kOriginalWindowsOtpPeriodKey] = [StringValue valueWithString:@(token.period).stringValue protected:YES];
        }
        
        if(token.digits != OTPToken.defaultDigits) {
            self.mutableCustomFields[kOriginalWindowsOtpLengthKey] = [StringValue valueWithString:@(token.digits).stringValue protected:YES];
        }
        
        if(token.algorithm != OTPToken.defaultAlgorithm) {
            if ( token.algorithm == OTPAlgorithmSHA256 ) {
                self.mutableCustomFields[kOriginalWindowsOtpAlgoKey] = [StringValue valueWithString:kOriginalWindowsOtpAlgoValueSha256 protected:YES];
            }
            else if ( token.algorithm == OTPAlgorithmSHA512 ) {
                self.mutableCustomFields[kOriginalWindowsOtpAlgoKey] = [StringValue valueWithString:kOriginalWindowsOtpAlgoValueSha512 protected:YES];
            }
        }
    }
}

- (void)setTotp:(OTPToken*)token appendUrlToNotes:(BOOL)appendUrlToNotes addLegacyFields:(BOOL)addLegacyFields addOtpAuthUrl:(BOOL)addOtpAuthUrl {
    if ( appendUrlToNotes ) {     
        self.notes = [self.notes stringByAppendingFormat:@"\n-----------------------------------------\nStrongbox TOTP Auth URL: [%@]", [token url:YES]];
    }
    else {
        NSString* base32Secret = token.secret.mmcg_base32String;

        if ( addLegacyFields ) {
            [self setLegacyTotpFields:base32Secret token:token];
        }

        
        
        if ( addOtpAuthUrl ) { 
            NSURL* otpauthUrl = [token url:YES];
            self.mutableCustomFields[kKeeOtpPluginKey] = [StringValue valueWithString:otpauthUrl.absoluteString protected:YES];
        }

        

        [self setWindowsKeePassTotpFields:base32Secret token:token];
    }
    
    self.hasCachedOtpToken = NO; 
}

- (void)clearTotp {
    
    
    
    
    self.mutableCustomFields[kOriginalWindowsSecretKey] = nil;
    self.mutableCustomFields[kOriginalWindowsSecretHexKey] = nil;
    self.mutableCustomFields[kOriginalWindowsSecretBase64Key] = nil;
    self.mutableCustomFields[kOriginalWindowsSecretBase32Key] = nil;
    self.mutableCustomFields[kOriginalWindowsOtpPeriodKey] = nil;
    self.mutableCustomFields[kOriginalWindowsOtpLengthKey] = nil;
    self.mutableCustomFields[kOriginalWindowsOtpAlgoKey] = nil;
    
    
    
    self.mutableCustomFields[kKeePassXcTotpSeedKey] = nil;
    self.mutableCustomFields[kKeePassXcTotpSettingsKey] = nil;
    
    
    
    
    self.mutableCustomFields[kKeeOtpPluginKey] = nil;
    
    
    
    NSTextCheckingResult *result = [[NodeFields totpNotesRegex] firstMatchInString:self.notes options:kNilOptions range:NSMakeRange(0, self.notes.length)];
    
    if(result) {
        slog(@"Found matching OTP in Notes: [%@]", [self.notes substringWithRange:result.range]);
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
        return [OTPToken tokenWithURL:url];
    }
    
    return nil;
}

+ (OTPToken*)getOtpTokenFromRecord:(NSString*)password
                            fields:(MutableOrderedDictionary<NSString*, StringValue*>*)fields
                             notes:(NSString*)notes
            usingLegacyKeeOtpStyle:(BOOL*)usingLegacyKeeOtpStyle {
    
    
    
    
    OTPToken* ret;
    
    
    
    NSURL *otpUrl = [NSURL URLWithString:password];
    ret = [NodeFields getOtpTokenFromUrl:otpUrl];
    if(ret) {
        return ret;
    }

    
    
    ret = [NodeFields getKeeOtpAndNewKeePassXCToken:fields usingLegacyKeeOtpStyle:usingLegacyKeeOtpStyle];
    if(ret) {
        return ret;
    }
    
    
    
    ret = [NodeFields getOriginalWindowsKeePassOTPToken:fields];
    if(ret) {
        return ret;
    }

    
    
    ret = [NodeFields getKeePassXCLegacyOTPToken:fields];
    if(ret) {
        return ret;
    }
    
    
    
    NSURL *url = [NodeFields findOtpUrlInString:notes];
    ret = [NodeFields getOtpTokenFromUrl:url];
    if ( ret ) {
        return ret;
    }
    
    
    
    return [NodeFields getKeeOtpLastResortFallback:fields];
}

+ (OTPToken*)getOriginalWindowsKeePassOTPToken:(MutableOrderedDictionary<NSString*, StringValue*>*)fields {
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    

    
    
    
    
    StringValue* secretBase32 = fields[kOriginalWindowsSecretBase32Key];
    StringValue* secretUtf8 = fields[kOriginalWindowsSecretKey];
    StringValue* secretHex = fields[kOriginalWindowsSecretHexKey];
    StringValue* secretBase64 = fields[kOriginalWindowsSecretBase64Key];

    NSData* secret;
    if ( secretBase32 && secretBase32.value.length ) {
        secret = secretBase32.value.dataFromBase32;
    }
    else if ( secretUtf8 && secretUtf8.value.length ) {
        secret = secretUtf8.value.utf8Data;
    }
    else if ( secretHex && secretHex.value.length) {
        secret = secretHex.value.dataFromHex;
    }
    else if ( secretBase64 && secretBase64.value.length ) {
        secret = secretBase64.value.dataFromBase64;
    }
    else {
        return nil;
    }

    OTPToken* token = [OTPToken tokenWithType:OTPTokenTypeTimer secret:secret];

    StringValue* length = fields[kOriginalWindowsOtpLengthKey];
    if (length && length.value.length) {
        int digits = length.value.intValue;
        if (digits > 0) {
            token.digits = digits;
        }
    }

    StringValue* period = fields[kOriginalWindowsOtpPeriodKey];
    if (period && period.value.length) {
        int p = period.value.intValue;
        if (p > 0) {
            token.period = p;
        }
    }

    StringValue* algo = fields[kOriginalWindowsOtpAlgoKey];
    if (algo && algo.value.length) {
        NSString* a = algo.value;
        if ( [a isEqualToString:kOriginalWindowsOtpAlgoValueSha256] ) {
            token.algorithm = OTPAlgorithmSHA256;
        }
        else if ( [a isEqualToString:kOriginalWindowsOtpAlgoValueSha512] ) {
            token.algorithm = OTPAlgorithmSHA512;
        }
    }
    
    return token;
}

+ (OTPToken*)getKeePassXCLegacyOTPToken:(MutableOrderedDictionary<NSString*, StringValue*>*)fields {
    
    
    
    
    
    StringValue* keePassXcOtpSecretEntry = fields[kKeePassXcTotpSeedKey];
    
    if(keePassXcOtpSecretEntry) {
        NSString* keePassXcOtpSecret = keePassXcOtpSecretEntry.value;
        if(keePassXcOtpSecret) {
            OTPToken* token = [OTPToken tokenWithType:OTPTokenTypeTimer secret:[NSData secretWithString:keePassXcOtpSecret]];
            
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

+ (nullable OTPToken*)getOtpTokenFromRecord:(NSString*)password fields:(MutableOrderedDictionary<NSString*, StringValue*>*)fields notes:(NSString*)notes {
    BOOL usingLegacyKeeOtpStyle;
    return [NodeFields getOtpTokenFromRecord:password fields:fields notes:notes usingLegacyKeeOtpStyle:&usingLegacyKeeOtpStyle];
}

+ (OTPToken*)getKeeOtpAndNewKeePassXCToken:(MutableOrderedDictionary<NSString*, StringValue*>*)fields usingLegacyKeeOtpStyle:(BOOL*)usingLegacyKeeOtpStyle {
    
    
    
    
    
    
    
    
    StringValue* keeOtpSecretEntry = fields[kKeeOtpPluginKey];
    
    if(!keeOtpSecretEntry) {
        return nil;
    }
    
    
    
    NSURL *url = [NSURL URLWithString:keeOtpSecretEntry.value];
    OTPToken* t = [NodeFields getOtpTokenFromUrl:url];
    if(t) {
        *usingLegacyKeeOtpStyle = NO;
        return t;
    }
    
    
    
    NSString* keeOtpSecret = keeOtpSecretEntry.value;
    if(!keeOtpSecret) {
        return nil;
    }
    
    NSDictionary *params = [NodeFields getQueryParams:keeOtpSecret];
    NSString* secret = params[@"key"];
    
    if(secret.length) {
        *usingLegacyKeeOtpStyle = YES; 
        
        
        
        if([secret containsString:@"%3d"]) {
            secret = [secret stringByRemovingPercentEncoding];
        }
        
        OTPToken* token = [OTPToken tokenWithType:OTPTokenTypeTimer secret:[NSData secretWithString:secret]];
        
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
    
    return nil;
}

+ (OTPToken*)getKeeOtpLastResortFallback:(MutableOrderedDictionary<NSString*, StringValue*>*)fields {
    
    
    
    
    
    
    StringValue* keeOtpSecretEntry = fields[kKeeOtpPluginKey];
    if(!keeOtpSecretEntry) {
        return nil;
    }
        
    
    
    NSString* keeOtpSecret = keeOtpSecretEntry.value;
    if(!keeOtpSecret) {
        return nil;
    }
    
    if ( [keeOtpSecret isEqualToString:@"30;6"] ) { 
        return nil;
    }
    
    OTPToken* token = [OTPToken tokenWithType:OTPTokenTypeTimer
                                       secret:[NSData secretWithString:keeOtpSecret]];
    
    if([token validate]) {
        return token;
    }
    
    return nil;
}

+ (NSURL*)findOtpUrlInString:(NSString*)urlString {
    if(!urlString.length) {
        return nil;
    }
    
    NSError* error;
    NSDataDetector* detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:&error];
    
    if(detector) {
        NSArray *matches = [detector matchesInString:urlString
                                             options:0
                                               range:NSMakeRange(0, [urlString length])];
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
        slog(@"Error creating data detector: %@", error);
    }
    
    return nil;
}



- (BOOL)expired {
    return self.expires != nil && self.expires.isInPast;
}

- (BOOL)nearlyExpired {
    if(self.expires == nil || self.expired) {
        return NO;
    }
 
    return [NodeFields nearlyExpired:self.expires];
}

+ (BOOL)nearlyExpired:(NSDate*)expires {
    if ( expires.isInPast ) {
        return NO;
    }
    
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *components = [gregorian components:NSCalendarUnitDay
                                                fromDate:[NSDate date]
                                                  toDate:expires
                                                 options:0];
    
    NSInteger days = [components day];

    return days < 14;
}



- (NSArray<NSString *> *)alternativeUrls {
    NSDictionary<NSString*, StringValue*> *filtered = [self.mutableCustomFields.dictionary filter:^BOOL(NSString * _Nonnull key, StringValue * _Nonnull value) {
        return [NodeFields isAlternativeURLCustomFieldKey:key];
    }];
    
    NSArray<NSString*>* values = [filtered map:^id _Nonnull(NSString * _Nonnull key, StringValue * _Nonnull value) {
        return value.value;
    }];
    
    return [values sortedArrayUsingComparator:finderStringComparator];
}

- (void)addSecondaryUrl:(NSString*)url optionalCustomFieldSuffixLabel:(NSString*_Nullable)optionalCustomFieldSuffixLabel {
    if ( url.length == 0 ) {
        slog(@"🔴 Nil or empty URL sent to addSecondaryURL");
        return;
    }
    
    NSString* customFieldDesiredName = @"URL-2";
    if ( optionalCustomFieldSuffixLabel.length ) {
        customFieldDesiredName = [NSString stringWithFormat:@"URL-%@", optionalCustomFieldSuffixLabel];
    }
    
    if ( self.mutableCustomFields[customFieldDesiredName] == nil ) {
        self.mutableCustomFields[customFieldDesiredName] = [StringValue valueWithString:url];
        return;
    }
    
    
    
    customFieldDesiredName = @"URL-";
    if ( optionalCustomFieldSuffixLabel.length ) {
        customFieldDesiredName = [NSString stringWithFormat:@"URL-%@-", optionalCustomFieldSuffixLabel];
    }

    NSString* suffixed;
    for ( int i = 2;i < INT_MAX;i++) {
        suffixed = [NSString stringWithFormat:@"%@%d", customFieldDesiredName, i];
        
        if ( self.mutableCustomFields[suffixed] == nil ) {
            self.mutableCustomFields[suffixed] = [StringValue valueWithString:url];
            return;
        }
        
    }
}



- (NSString *)email {
    StringValue* val = self.customFields[kCanonicalEmailFieldName];
    return val ? val.value : @"";
}

- (void)setEmail:(NSString *)email {
    if ( email.length ) {
        [self setCustomField:kCanonicalEmailFieldName value:[StringValue valueWithString:email]];
    }
    else {
        [self removeCustomField:kCanonicalEmailFieldName];
    }
}



- (BOOL)isAutoFillExcluded {
    ValueWithModDate* vmd = self.customData[kIsExcludedFromAutoFillCustomDataKey];
    
    return vmd && vmd.value.isKeePassXmlBooleanStringTrue; 
}

- (void)setIsAutoFillExcluded:(BOOL)isAutoFillExcluded {
    if ( isAutoFillExcluded ) {
        self.customData[kIsExcludedFromAutoFillCustomDataKey] = [ValueWithModDate value:kAttributeValueTrue modified:NSDate.date];
    }
    else {
        self.customData[kIsExcludedFromAutoFillCustomDataKey] = nil;
    }
}



- (NSString *)description {
    return [NSString stringWithFormat:@"{ username = [%@]\nurl = [%@]\n}", self.username, self.url];
}

@end
