//
//  OfflineCacheNameDetector.h
//  Strongbox-iOS
//
//  Created by Mark on 27/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OfflineCacheNameDetector : NSObject

+ (BOOL)nickNameMatchesOldOfflineCache:(NSString*)nickName;

@end

NS_ASSUME_NONNULL_END
