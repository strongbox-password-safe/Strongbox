//
//  ClipboardManager.m
//  Strongbox
//
//  Created by Mark on 18/09/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "ClipboardManager.h"

#import <UIKit/UIKit.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import "SharedAppAndAutoFillSettings.h"

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
        if(SharedAppAndAutoFillSettings.sharedInstance.clearClipboardEnabled && SharedAppAndAutoFillSettings.sharedInstance.clearClipboardAfterSeconds > 0) {
            
            
            
            NSDate* expirationTime = [NSDate.date dateByAddingTimeInterval:SharedAppAndAutoFillSettings.sharedInstance.clearClipboardAfterSeconds];
            
            NSLog(@"Expiration: %@", expirationTime);
            
            [pasteboard setItems:@[@{ ((NSString*)kUTTypeUTF8PlainText) : value }]
                         options: @{ UIPasteboardOptionLocalOnly : @(!SharedAppAndAutoFillSettings.sharedInstance.clipboardHandoff) ,
                                     UIPasteboardOptionExpirationDate : expirationTime }];
        }
        else {
            [pasteboard setItems:@[@{ ((NSString*)kUTTypeUTF8PlainText) : value }]
                         options: @{ UIPasteboardOptionLocalOnly : @(!SharedAppAndAutoFillSettings.sharedInstance.clipboardHandoff) }];
        }
    }
    else {
        [pasteboard setString:value];
    }
}

#ifndef IS_APP_EXTENSION

- (void)onClipboardChangedNotification:(NSNotification*)note {
    NSLog(@"onClipboardChangedNotification: [%@]", note);
    
    if (@available(ios 10.0, *)) {
        if(![UIPasteboard.generalPasteboard hasStrings] &&
           ![UIPasteboard.generalPasteboard hasImages] &&
           ![UIPasteboard.generalPasteboard hasURLs]) {
            return;
        }
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
    
    NSLog(@"Creating New Clear Clipboard Background Task... with timeout = [%ld]", (long)SharedAppAndAutoFillSettings.sharedInstance.clearClipboardAfterSeconds);

    NSInteger clipboardChangeCount = UIPasteboard.generalPasteboard.changeCount;
    self.clearClipboardTask = dispatch_block_create(0, ^{
        [self clearClipboardDelayedTask:clipboardChangeCount];
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(SharedAppAndAutoFillSettings.sharedInstance.clearClipboardAfterSeconds * NSEC_PER_SEC)),
                    dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), self.clearClipboardTask);
}

- (void)clearClipboardDelayedTask:(NSInteger)clipboardChangeCount {
    if(!SharedAppAndAutoFillSettings.sharedInstance.clearClipboardEnabled) {
        [self unobserveClipboardChangeNotifications];
        return; 
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
    if(SharedAppAndAutoFillSettings.sharedInstance.clearClipboardEnabled) {
        if(!self.clipboardNotificationIdentifier) {
            
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

#endif 

@end
