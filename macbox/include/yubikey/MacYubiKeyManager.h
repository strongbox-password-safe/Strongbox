//
//  YubiKeyManager.h
//  Strongbox
//
//  Created by Mark on 18/02/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MacYubiKeyManager : NSObject

+ (instancetype)sharedInstance;

- (void)doIt;

@end

NS_ASSUME_NONNULL_END
