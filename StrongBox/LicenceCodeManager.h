//
//  LicenceCodeManager.h
//  Strongbox-iOS
//
//  Created by Mark on 11/02/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^VerifyCompletionBlock)(BOOL success, NSError * _Nullable error);

@interface LicenceCodeManager : NSObject

+ (instancetype)sharedInstance;

- (void)verifyCode:(NSString*)code completion:(VerifyCompletionBlock)completion;

@end

NS_ASSUME_NONNULL_END
