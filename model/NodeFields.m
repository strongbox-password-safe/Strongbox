//
//  NodeFields.m
//  MacBox
//
//  Created by Mark on 31/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "NodeFields.h"
#import "NSArray+Extensions.h"

#import "OTPToken+Serialization.h"
#import "OTPToken+Generation.h"
#import "NSURL+QueryItems.h"
#import <Base32/MF_Base32Additions.h>

static NSString* const kOtpAuthScheme = @"otpauth";

@interface NodeFields ()

@property BOOL hasCachedOtpToken;
@property OTPToken* cachedOtpToken;
@property NSMutableDictionary<NSString*, StringValue*> *mutableCustomFields;

@end

@implementation NodeFields

+ (NSRegularExpression *)regex
{
    static NSRegularExpression *_regex;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        _regex = [NSRegularExpression regularExpressionWithPattern:@"\n-----------------------------------------\nStrongbox TOTP Auth URL: \\[.*\\]" options:NSRegularExpressionDotMatchesLineSeparators error:Nil];
    });
    
    return _regex;
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
        self.created = [NSDate date];
        self.modified = [NSDate date];
        self.accessed = [NSDate date];
        self.passwordModified = [NSDate date];
        self.attachments = [NSMutableArray array];
        self.mutableCustomFields = [NSMutableDictionary dictionary];
        self.keePassHistory = [NSMutableArray array];
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

- (NodeFields*)duplicate {
    NodeFields* ret = [[NodeFields alloc] initWithUsername:self.username
                                                       url:self.url
                                                  password:self.password
                                                     notes:self.notes
                                                     email:self.email];
    
    ret.passwordModified = self.passwordModified;
    ret.expires = self.expires;
    ret.attachments = [self cloneAttachments];
    ret.mutableCustomFields = [self cloneCustomFields];
    
    return ret;
}

- (NodeFields *)cloneForHistory {
    NodeFields* ret = [[NodeFields alloc] initWithUsername:self.username url:self.url password:self.password notes:self.notes email:self.email];

    ret.created = self.created;
    ret.modified = self.modified;
    ret.accessed = self.accessed;
    ret.passwordModified = self.passwordModified;
    ret.expires = self.expires;
    ret.attachments = [self cloneAttachments];
    ret.mutableCustomFields = [self cloneCustomFields];
    
    // Empty History
    ret.keePassHistory = [NSMutableArray array];
    
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// TOTP

- (OTPToken *)otpToken {
    if(!self.hasCachedOtpToken) {
        self.cachedOtpToken = [NodeFields getOtpTokenFromRecord:self.password fields:self.customFields notes:self.notes];
        self.hasCachedOtpToken = YES;
    }
    
    return self.cachedOtpToken;
}

- (BOOL)setTotpWithString:(NSString *)string appendUrlToNotes:(BOOL)appendUrlToNotes forceSteam:(BOOL)forceSteam {
    OTPToken* token = [NodeFields getOtpTokenFromString:string forceSteam:forceSteam];
    
    if(token) {
        [self setTotp:token appendUrlToNotes:appendUrlToNotes];
        return YES;
    }
    
    return NO;
}

+ (OTPToken*)getOtpTokenFromString:(NSString * _Nonnull)string forceSteam:(BOOL)forceSteam {
    OTPToken *token = nil;
    NSURL *url = [self findOtpUrlInString:string];
    
    if(url) {
        token = [self getOtpTokenFromUrl:url];
    }
    else {
        NSData* secretData = [NSData secretWithString:string];
        if(secretData) {
            token = [OTPToken tokenWithType:OTPTokenTypeTimer secret:secretData name:@"<Unknown>" issuer:@"<Unknown>"];
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
        // Set Common TOTP Fields.. and append to Notes if asked to (usually for Password Safe dbs)
        // KeePassXC Otp
        
        self.mutableCustomFields[@"TOTP Seed"] = [StringValue valueWithString:[token.secret base32String] protected:YES];
        
        if(token.algorithm == OTPAlgorithmSteam) {
            NSString* valueString = [NSString stringWithFormat:@"%lu;S", (unsigned long)token.period];
            self.mutableCustomFields[@"TOTP Settings"] = [StringValue valueWithString:valueString protected:YES];
        }
        else {
            NSString* valueString = [NSString stringWithFormat:@"%lu;%lu", (unsigned long)token.period, (unsigned long)token.digits];
            self.mutableCustomFields[@"TOTP Settings"] = [StringValue valueWithString:valueString protected:YES];
        }
        
        // KeeOtp Plugin
        // * otp="key=2GQFLXXUBJQELC&step=31"
        
        NSURLComponents *components = [NSURLComponents componentsWithString:@"http://strongboxsafe.com"];
        NSURLQueryItem *key = [NSURLQueryItem queryItemWithName:@"key" value:[token.secret base32String]];
        
        if(token.period != OTPToken.defaultPeriod || token.digits != OTPToken.defaultDigits) {
            NSURLQueryItem *step = [NSURLQueryItem queryItemWithName:@"step" value:[NSString stringWithFormat: @"%lu", (unsigned long)token.period]];
            NSURLQueryItem *size = [NSURLQueryItem queryItemWithName:@"size" value:[NSString stringWithFormat: @"%lu", (unsigned long)token.digits]];
            components.queryItems = @[key, step, size];
        }
        else {
            components.queryItems = @[key];
        }
        self.mutableCustomFields[@"otp"] = [StringValue valueWithString:components.query protected:YES];
    }
    
    self.hasCachedOtpToken = NO; // Force Reload of TOTP as may have changed with this change
}

- (void)clearTotp {
    // Set Common TOTP Fields.. and append to Notes if asked to (usually for Password Safe dbs)
    
    // KeePassXC Otp
    
    self.mutableCustomFields[@"TOTP Seed"] = nil;
    self.mutableCustomFields[@"TOTP Settings"] = nil;
    
    // KeeOtp Plugin
    // * otp="key=2GQFLXXUBJQELC&step=31"
    
    self.mutableCustomFields[@"otp"] = nil;
    
    // Notes Field if it's a Password Safe database
    
    NSTextCheckingResult *result = [[NodeFields regex] firstMatchInString:self.notes options:kNilOptions range:NSMakeRange(0, self.notes.length)];
    
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
        NSDictionary *params = [self getQueryParams:url.query];
        if(params[@"encoder"] && [params[@"encoder"] isEqualToString:@"steam"]) {
            //            NSLog(@"Steam Encoder on OTPAuth URL Found");
            ret.algorithm = OTPAlgorithmSteam;
            ret.digits = 5;
        }
        
        return ret;
    }
    
    return nil;
}

+ (OTPToken*)getOtpTokenFromRecord:(NSString*)password fields:(NSDictionary<NSString*, StringValue*>*)fields notes:(NSString*)notes {
    // KyPass - OTPAuth url in the Password field…
    
    NSURL *otpUrl = [NSURL URLWithString:password];
    
    OTPToken* ret = [self getOtpTokenFromUrl:otpUrl];
    if(ret) {
        return ret;
    }
    
    // KeePassXC
    // * []TOTP Seed=<seed>
    // * []TOTP Settings=30;6 - time and digits - can be 30;S for “Steam”
    
    StringValue* keePassXcOtpSecretEntry = fields[@"TOTP Seed"];
    
    if(keePassXcOtpSecretEntry) {
        NSString* keePassXcOtpSecret = keePassXcOtpSecretEntry.value;
        if(keePassXcOtpSecret) {
            OTPToken* token = [OTPToken tokenWithType:OTPTokenTypeTimer secret:[NSData secretWithString:keePassXcOtpSecret] name:@"<Unknown>" issuer:@"<Unknown>"];
            
            StringValue* keePassXcOtpParamsEntry = fields[@"TOTP Settings"];
            
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
    
    // KeeOtp Plugin
    // * otp="key=2GQFLXXUBJQELC&step=31"
    // * otp="key=2GQFLXXUBJQELC&size=8"
    
    StringValue* keeOtpSecretEntry = fields[@"otp"];
    
    if(keeOtpSecretEntry) {
        NSString* keeOtpSecret = keeOtpSecretEntry.value;
        if(keeOtpSecret) {
            NSDictionary *params = [self getQueryParams:keeOtpSecret];
            NSString* secret = params[@"key"];
            
            if(secret.length) {
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
                
                if([token validate])
                {
                    return token;
                }
            }
        }
    }
    
    // See if you can find an OTPAuth URL in the Notes field...
    
    NSURL *url = [self findOtpUrlInString:notes];
    
    return [self getOtpTokenFromUrl:url];
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

-(NSString *)description {
    return [NSString stringWithFormat:@"{\n    password = [%@]\n    username = [%@]\n    email = [%@]\n    url = [%@]\n}",
            self.password,
            self.username,
            self.email,
            self.url];
}

@end
