//
//  YubiManager.h
//  Strongbox-iOS
//
//  Created by Mark on 28/09/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface YubiManager : NSObject


+ (instancetype)sharedInstance;

- (void)doIt;

@end

NS_ASSUME_NONNULL_END
