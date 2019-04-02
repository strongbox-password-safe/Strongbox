//
//  Node+OtpToken.h
//  Strongbox
//
//  Created by Mark on 20/01/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Node.h"

NS_ASSUME_NONNULL_BEGIN

@interface Node (OtpToken)

@property (nonatomic, readonly) OTPToken* otpToken;
+ (nullable OTPToken*)getOtpTokenFromRecord:(NSString*)password fields:(NSDictionary*)fields notes:(NSString*)notes; // Unit Testing

- (BOOL)setTotpWithString:(NSString *)string appendUrlToNotes:(BOOL)appendUrlToNotes;
- (void)clearTotp;

@end

NS_ASSUME_NONNULL_END
