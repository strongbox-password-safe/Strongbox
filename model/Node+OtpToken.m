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

static NSString* const kOtpAuthScheme = @"otpauth";

@implementation Node (OtpToken)

-(OTPToken *)otpToken {
    return [Node getOtpTokenFromRecord:self.fields.password fields:self.fields.customFields notes:self.fields.notes];
}

- (BOOL)setTotpWithString:(NSString *)string appendUrlToNotes:(BOOL)appendUrlToNotes {
    NSURL* url = [Node findOtpUrlInString:string];
    OTPToken* token = nil;
    
    if(url) {
        token = [OTPToken tokenWithURL:url];
    }
    else {
        NSData* secretData = [NSData secretWithString:string];
        if(secretData) {
            token = [OTPToken tokenWithType:OTPTokenTypeTimer secret:secretData name:@"<Unknown>" issuer:@"<Unknown>"];
            token = [token validate] ? token : nil;
        }
    }

    if(token) {
        return [self setTotp:token appendUrlToNotes:appendUrlToNotes && url ? url.absoluteString : nil];
    }

    return NO;
}

- (BOOL)setTotp:(OTPToken*)token appendUrlToNotes:(NSString*)appendUrlToNotes {
    if(token) {
        // Set Common TOTP Fields.. and append to Notes if asked to (usually for Password Safe dbs)
        
        // KeePassXC Otp
        
        self.fields.customFields[@"TOTP Seed"] = [StringValue valueWithString:[token.secret base32String] protected:YES];
        
        if(token.period != OTPToken.defaultPeriod || token.digits != OTPToken.defaultDigits) {
            NSString* valueString = [NSString stringWithFormat:@"%lu;%lu", (unsigned long)token.period, (unsigned long)token.digits];
            self.fields.customFields[@"TOTP Settings"] = [StringValue valueWithString:valueString protected:YES];
        }
        else {
            self.fields.customFields[@"TOTP Settings"] = nil;
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
            self.fields.notes = [self.fields.notes stringByAppendingFormat:@"\n-----------------------------------------\nStrongbox TOTP Auth URL: [%@]", appendUrlToNotes];
        }
        
        return YES;
    }

    return NO;
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
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\n-----------------------------------------\nStrongbox TOTP Auth URL: \\[.*\\]" options:NSRegularExpressionDotMatchesLineSeparators error:Nil];

    NSTextCheckingResult *result = [regex firstMatchInString:self.fields.notes options:kNilOptions range:NSMakeRange(0, self.fields.notes.length)];
    
    if(result) {
        NSLog(@"Found matching OTP in Notes: [%@]", [self.fields.notes substringWithRange:result.range]);
        self.fields.notes = [self.fields.notes stringByReplacingCharactersInRange:result.range withString:@""];
    }
}

+ (OTPToken*)getOtpTokenFromRecord:(NSString*)password fields:(NSDictionary<NSString*, StringValue*>*)fields notes:(NSString*)notes {
    // KyPass - OTPAuth url in the Password field…
    
    NSURL *otpUrl = [NSURL URLWithString:password];
    
    if(otpUrl && otpUrl.scheme && [otpUrl.scheme isEqualToString:kOtpAuthScheme]) {
        OTPToken* ret = [OTPToken tokenWithURL:otpUrl];
        if(ret) {
            return ret;
        }
    }
    
    // KeePassXC
    // * []TOTP Seed=<seed>
    // * []TOTP Settings=30;6 - time and digits - can be 30;S for “Steam”?
    
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
                    if(params.count > 1 && ![params[1] isEqualToString:@"S"]) { // S = Steam? Not sure how to gen... FUTURE
                        token.digits = [params[1] integerValue];
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
            NSURLComponents *components = [NSURLComponents new];
            [components setQuery:keeOtpSecret];
            NSArray *queryItems = components.queryItems;
            NSMutableDictionary *params = [NSMutableDictionary dictionaryWithCapacity:queryItems.count];
            for (NSURLQueryItem *item in queryItems) {
                params[item.name] = item.value;
            }
            
            NSString* secret = params[@"key"];
            
            if(secret.length) {
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

    if(url) {
        return [OTPToken tokenWithURL:url];
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

@end
