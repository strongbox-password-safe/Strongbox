//
//  Node+OtpToken.m
//  Strongbox
//
//  Created by Mark on 20/01/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "Node+OtpToken.h"
#import "OTPToken+Serialization.h"
#import "OTPToken+Generation.h"
#import "NSURL+QueryItems.h"
#import <Base32/MF_Base32Additions.h>
#import "OTPToken+Generation.h"

static NSString* const kOtpAuthScheme = @"otpauth";

@implementation Node (OtpToken)

+ (NSRegularExpression *)regex
{
    static NSRegularExpression *_regex;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        _regex = [NSRegularExpression regularExpressionWithPattern:@"\n-----------------------------------------\nStrongbox TOTP Auth URL: \\[.*\\]" options:NSRegularExpressionDotMatchesLineSeparators error:Nil];
    });
    
    return _regex;
}

- (OTPToken *)otpToken {
    return [Node getOtpTokenFromRecord:self.fields.password fields:self.fields.customFields notes:self.fields.notes];
}

- (BOOL)setTotpWithString:(NSString *)string appendUrlToNotes:(BOOL)appendUrlToNotes forceSteam:(BOOL)forceSteam {
    OTPToken* token = [Node getOtpTokenFromString:string forceSteam:forceSteam];
    
    if(token) {
        [self setTotp:token appendUrlToNotes:appendUrlToNotes];
        return YES;
    }
    
    return NO;
}

+ (OTPToken*)getOtpTokenFromString:(NSString * _Nonnull)string forceSteam:(BOOL)forceSteam {
    OTPToken *token = nil;
    NSURL *url = [Node findOtpUrlInString:string];

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
    // Set Common TOTP Fields.. and append to Notes if asked to (usually for Password Safe dbs)
    
    // KeePassXC Otp
    
    self.fields.customFields[@"TOTP Seed"] = [StringValue valueWithString:[token.secret base32String] protected:YES];
    
    if(token.algorithm == OTPAlgorithmSteam) {
        NSString* valueString = [NSString stringWithFormat:@"%lu;S", (unsigned long)token.period];
        self.fields.customFields[@"TOTP Settings"] = [StringValue valueWithString:valueString protected:YES];
    }
    else {
        NSString* valueString = [NSString stringWithFormat:@"%lu;%lu", (unsigned long)token.period, (unsigned long)token.digits];
        self.fields.customFields[@"TOTP Settings"] = [StringValue valueWithString:valueString protected:YES];
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
    self.fields.customFields[@"otp"] = [StringValue valueWithString:components.query protected:YES];

    // Notes Field if it's a Password Safe database
    
    if(appendUrlToNotes) {
        self.fields.notes = [self.fields.notes stringByAppendingFormat:@"\n-----------------------------------------\nStrongbox TOTP Auth URL: [%@]", [token url:YES]];
    }
}

- (void)clearTotp {
    // Set Common TOTP Fields.. and append to Notes if asked to (usually for Password Safe dbs)
    
    // KeePassXC Otp
    
    self.fields.customFields[@"TOTP Seed"] = nil;
    self.fields.customFields[@"TOTP Settings"] = nil;
    
    // KeeOtp Plugin
    // * otp="key=2GQFLXXUBJQELC&step=31"
    
    self.fields.customFields[@"otp"] = nil;
    
    // Notes Field if it's a Password Safe database
    
    NSTextCheckingResult *result = [[Node regex] firstMatchInString:self.fields.notes options:kNilOptions range:NSMakeRange(0, self.fields.notes.length)];
    
    if(result) {
        NSLog(@"Found matching OTP in Notes: [%@]", [self.fields.notes substringWithRange:result.range]);
        self.fields.notes = [self.fields.notes stringByReplacingCharactersInRange:result.range withString:@""];
    }
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
            NSLog(@"Steam Encoder on OTPAuth URL Found");
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

    NSURL *url = [Node findOtpUrlInString:notes];

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

@end
