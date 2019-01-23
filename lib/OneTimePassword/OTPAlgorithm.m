//
//  OTPAlgorithm.m
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

#import "OTPAlgorithm.h"


OTPAlgorithm OTPAlgorithmUnknown = UINT8_MAX;


#pragma mark - String Representations

NSString *const kOTPAlgorithmSHA1 = @"SHA1";
NSString *const kOTPAlgorithmSHA256 = @"SHA256";
NSString *const kOTPAlgorithmSHA512 = @"SHA512";


@implementation NSString (OTPAlgorithm)

+ (instancetype)stringForAlgorithm:(OTPAlgorithm)algorithm
{
    switch (algorithm) {
        case OTPAlgorithmSHA1:
            return kOTPAlgorithmSHA1;
        case OTPAlgorithmSHA256:
            return kOTPAlgorithmSHA256;
        case OTPAlgorithmSHA512:
            return kOTPAlgorithmSHA512;
    }
}

- (OTPAlgorithm)algorithmValue
{
    if ([self isEqualToString:kOTPAlgorithmSHA1]) {
        return OTPAlgorithmSHA1;
    } else if ([self isEqualToString:kOTPAlgorithmSHA256]) {
        return OTPAlgorithmSHA256;
    } else if ([self isEqualToString:kOTPAlgorithmSHA512]) {
        return OTPAlgorithmSHA512;
    }

    return OTPAlgorithmUnknown;
}

@end
