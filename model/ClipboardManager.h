//
//  ClipboardManager.h
//  Strongbox
//
//  Created by Mark on 18/09/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ClipboardManager : NSObject

+ (instancetype)sharedInstance;

- (void)copyStringWithDefaultExpiration:(NSString*)value;

#ifndef IS_APP_EXTENSION

- (void)observeClipboardChangeNotifications;

#endif // !IS_APP_EXTENSION

@end

NS_ASSUME_NONNULL_END
