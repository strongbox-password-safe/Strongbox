//
//  SystemTrayViewController.h
//  MacBox
//
//  Created by Strongbox on 18/08/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface SystemTrayViewController : NSViewController

+ (instancetype)instantiateFromStoryboard;

@property (nonatomic, copy) void (^onShowClicked)(NSString*_Nullable databaseToShowUuid);

@property (weak) NSPopover* popover;

@end

NS_ASSUME_NONNULL_END
