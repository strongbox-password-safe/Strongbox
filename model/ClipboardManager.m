//
//  ClipboardManager.m
//  Strongbox
//
//  Created by Mark on 18/09/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "ClipboardManager.h"

#import <UIKit/UIKit.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import "Settings.h"

@interface ClipboardManager ()

@property dispatch_block_t clearClipboardTask;
@property UIBackgroundTaskIdentifier clearClipboardAppBackgroundTask;
@property NSObject* clipboardNotificationIdentifier;

@end

@implementation ClipboardManager

+ (instancetype)sharedInstance {
    static ClipboardManager *sharedInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sharedInstance = [[ClipboardManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.clearClipboardAppBackgroundTask = UIBackgroundTaskInvalid;
    }
    return self;
}

- (void)copyStringWithDefaultExpiration:(NSString *)value {
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    
    if(@available(iOS 10.0, *)) {
        if(Settings.sharedInstance.clearClipboardEnabled && Settings.sharedInstance.clearClipboardAfterSeconds > 0) {
            // Belt and braces approach here we can use the built in iOS 10+ expiry along with our
            // more manual clipboard watch task to catch other cases where we don't directly copy via this function
            
            NSDate* expirationTime = [NSDate.date dateByAddingTimeInterval:Settings.sharedInstance.clearClipboardAfterSeconds];
            
            NSLog(@"Expiration: %@", expirationTime);
            
            [pasteboard setItems:@[@{ ((NSString*)kUTTypeUTF8PlainText) : value }]
                         options: @{ UIPasteboardOptionLocalOnly : @(!Settings.sharedInstance.clipboardHandoff) ,
                                     UIPasteboardOptionExpirationDate : expirationTime }];
        }
        else {
            [pasteboard setItems:@[@{ ((NSString*)kUTTypeUTF8PlainText) : value }]
                         options: @{ UIPasteboardOptionLocalOnly : @(!Settings.sharedInstance.clipboardHandoff) }];
        }
    }
    else {
        [pasteboard setString:value];
    }
}

#ifndef IS_APP_EXTENSION

- (void)onClipboardChangedNotification:(NSNotification*)note {
    NSLog(@"onClipboardChangedNotification: [%@]", note);
    
    if(![UIPasteboard.generalPasteboard hasStrings] &&
       ![UIPasteboard.generalPasteboard hasImages] &&
       ![UIPasteboard.generalPasteboard hasURLs]) {
        return;
    }

    UIApplication* app = [UIApplication sharedApplication];
    if(self.clearClipboardTask) {
        NSLog(@"Clearing existing clear clipboard tasks");
        dispatch_block_cancel(self.clearClipboardTask);
        self.clearClipboardTask = nil;
        if(self.clearClipboardAppBackgroundTask != UIBackgroundTaskInvalid) {
            [app endBackgroundTask:self.clearClipboardAppBackgroundTask];
            self.clearClipboardAppBackgroundTask = UIBackgroundTaskInvalid;
        }
    }

    self.clearClipboardAppBackgroundTask = [app beginBackgroundTaskWithExpirationHandler:^{
        [app endBackgroundTask:self.clearClipboardAppBackgroundTask];
        self.clearClipboardAppBackgroundTask = UIBackgroundTaskInvalid;
    }];
    
    NSLog(@"Creating New Clear Clipboard Background Task... with timeout = [%ld]", (long)Settings.sharedInstance.clearClipboardAfterSeconds);

    NSInteger clipboardChangeCount = UIPasteboard.generalPasteboard.changeCount;
    self.clearClipboardTask = dispatch_block_create(0, ^{
        [self clearClipboardDelayedTask:clipboardChangeCount];
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(Settings.sharedInstance.clearClipboardAfterSeconds * NSEC_PER_SEC)),
                    dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), self.clearClipboardTask);
}

- (void)clearClipboardDelayedTask:(NSInteger)clipboardChangeCount {
    if(!Settings.sharedInstance.clearClipboardEnabled) {
        [self unobserveClipboardChangeNotifications];
        return; // In case a setting change has be made
    }
    
    if(clipboardChangeCount == UIPasteboard.generalPasteboard.changeCount) {
        NSLog(@"Clearing Clipboard...");
        
        [self unobserveClipboardChangeNotifications];
        
        [UIPasteboard.generalPasteboard setStrings:@[]];
        [UIPasteboard.generalPasteboard setImages:@[]];
        [UIPasteboard.generalPasteboard setURLs:@[]];
        
        [self observeClipboardChangeNotifications];
    }
    else {
        NSLog(@"Not clearing clipboard as change count does not match.");
    }
    
    UIApplication* app = [UIApplication sharedApplication];
    [app endBackgroundTask:self.clearClipboardAppBackgroundTask];
    self.clearClipboardAppBackgroundTask = UIBackgroundTaskInvalid;
    self.clearClipboardTask = nil;
}

- (void)observeClipboardChangeNotifications {
    if(Settings.sharedInstance.clearClipboardEnabled) {
        if(!self.clipboardNotificationIdentifier) {
            // Delay by a small bit because we're definitely getting an odd crash or two somehow due to infinite loop now
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self.clipboardNotificationIdentifier =
                [NSNotificationCenter.defaultCenter addObserverForName:UIPasteboardChangedNotification
                                                                object:nil
                                                                 queue:nil
                                                            usingBlock:^(NSNotification * _Nonnull note) {
                                                                [self onClipboardChangedNotification:note];
                                                            }];
            });
        }
    }
}

- (void)unobserveClipboardChangeNotifications {
    if(self.clipboardNotificationIdentifier) {
        [NSNotificationCenter.defaultCenter removeObserver:self.clipboardNotificationIdentifier];
        self.clipboardNotificationIdentifier = nil;
    }
}

#endif // !IS_APP_EXTENSION

@end
