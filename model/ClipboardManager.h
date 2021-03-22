//
//  ClipboardManager.h
//  Strongbox
//
//  Created by Mark on 18/09/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ClipboardManager : NSObject

+ (instancetype)sharedInstance;

- (void)copyStringWithDefaultExpiration:(NSString*)value;
- (void)copyStringWithNoExpiration:(NSString *)value;

#ifndef IS_APP_EXTENSION

- (void)observeClipboardChangeNotifications;

#endif 

@end

NS_ASSUME_NONNULL_END
