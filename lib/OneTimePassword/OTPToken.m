//
//  OTPToken.m
//  Authenticator
//
//  Copyright (c) 2013 Matt Rubin
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//  the Software, and to permit persons to whom the Software is furnished to do so,
//  subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//  FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//  COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "OTPToken.h"


static NSString *const OTPTokenInternalTimerNotification = @"OTPTokenInternalTimerNotification";


@implementation OTPToken

- (id)init
{
    self = [super init];
    if (self) {
        self.algorithm = [self.class defaultAlgorithm];
        self.digits = [self.class defaultDigits];
        self.counter = [self.class defaultInitialCounter];
        self.period = [self.class defaultPeriod];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updatePasswordIfNeeded)
                                                     name:OTPTokenInternalTimerNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:OTPTokenInternalTimerNotification
                                                  object:nil];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p> type: %u, name: %@, algorithm: %@, digits: %lu",
            self.class, self, self.type, self.name, [NSString stringForAlgorithm:self.algorithm], (unsigned long)self.digits];
}

+ (instancetype)tokenWithType:(OTPTokenType)type secret:(NSData *)secret name:(NSString *)name issuer:(NSString *)issuer
{
    OTPToken *token = [[OTPToken alloc] init];
    token.type = type;
    token.secret = secret;
    token.name = name;
    token.issuer = issuer;
    return token;
}


#pragma mark - Defaults

+ (OTPAlgorithm)defaultAlgorithm
{
    return OTPAlgorithmSHA1;
}

+ (NSUInteger)defaultDigits
{
    return 6;
}

+ (uint64_t)defaultInitialCounter
{
    return 1;
}

+ (NSTimeInterval)defaultPeriod
{
    return 30;
}


#pragma mark - Validation

- (BOOL)validate
{
    BOOL validType = (self.type == OTPTokenTypeCounter) || (self.type == OTPTokenTypeTimer);
    BOOL validSecret = !!self.secret.length;
    BOOL validAlgorithm = (self.algorithm == OTPAlgorithmSHA1 ||
                           self.algorithm == OTPAlgorithmSHA256 ||
                           self.algorithm == OTPAlgorithmSHA512);
    BOOL validDigits = (self.digits <= 8) && (self.digits >= 6);

    BOOL validPeriod = (self.period > 0) && (self.period <= 300);

    return validType && validSecret && validAlgorithm && validDigits && validPeriod;
}


#pragma mark - Timed update

+ (void)load
{
    static NSTimer *sharedTimer = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedTimer = [NSTimer scheduledTimerWithTimeInterval:1
                                                       target:self
                                                     selector:@selector(updateAllTokens)
                                                     userInfo:nil
                                                      repeats:YES];
        // Ensure this timer fires right at the beginning of every second
        sharedTimer.fireDate = [NSDate dateWithTimeIntervalSince1970:floor(sharedTimer.fireDate.timeIntervalSince1970)+.01];
    });
}

+ (void)updateAllTokens
{
    [[NSNotificationCenter defaultCenter] postNotificationName:OTPTokenInternalTimerNotification object:self];
}

- (void)updatePasswordIfNeeded
{
    if (self.type != OTPTokenTypeTimer) return;

    NSTimeInterval allTime = [NSDate date].timeIntervalSince1970;
    uint64_t newCount = (uint64_t)allTime / (uint64_t)self.period;
    if (newCount > self.counter) {
        self.counter = newCount;
    }
}

@end
