//
//  ProgressWindow.h
//  Strongbox
//
//  Created by Mark on 08/12/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface ProgressWindow : NSWindowController

+ (instancetype)newProgress:(NSString *)status;
- (void)hide;

@end

NS_ASSUME_NONNULL_END
