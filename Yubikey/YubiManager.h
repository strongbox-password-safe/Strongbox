//
//  YubiManager.h
//  Strongbox-iOS
//
//  Created by Mark on 28/09/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "YubiKeyHardwareConfiguration.h"
#import "CompositeKeyFactors.h" // for YubiKeyCRResponseBlock

NS_ASSUME_NONNULL_BEGIN

//typedef void (^ChallengeResponseCompletion)(NSData*_Nullable response, NSError *_Nullable error);

@interface YubiManager : NSObject

+ (instancetype)sharedInstance;

- (BOOL)yubiKeySupportedOnDevice;

- (void)getResponse:(YubiKeyHardwareConfiguration*)configuration
          challenge:(NSData*)challenge
         completion:(YubiKeyCRResponseBlock)completion;

@end

NS_ASSUME_NONNULL_END
