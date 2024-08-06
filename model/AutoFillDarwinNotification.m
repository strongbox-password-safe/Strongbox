//
//  AutoFillDarwinNotification.m
//  Strongbox
//
//  Created by Strongbox on 03/10/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

#import "AutoFillDarwinNotification.h"
#import "SBLog.h"

static NSString* const kAutoFillDarwinNotificationIdentifier = @"AutoFillDarwinNotification";

static AutoFillDarwinCompletionBlock completionBlock;

@implementation AutoFillDarwinNotification

+ (void)sendNotification {
    slog(@"🟢 sendNotificationForMessageWithIdentifier");
    
    CFNotificationCenterRef const center = CFNotificationCenterGetDarwinNotifyCenter();
    CFDictionaryRef const userInfo = NULL;
    BOOL const deliverImmediately = YES;
    CFStringRef str = (__bridge CFStringRef)kAutoFillDarwinNotificationIdentifier;
    CFNotificationCenterPostNotification(center, str, NULL, userInfo, deliverImmediately);
}

+ (void)registerForNotifications:(AutoFillDarwinCompletionBlock)completion {
    slog(@"🟢 registerForNotificationsWithIdentifier");
    
    [self unregisterForNotifications];
    
    completionBlock = completion;
    
    CFNotificationCenterRef const center = CFNotificationCenterGetDarwinNotifyCenter();
    CFStringRef str = (__bridge CFStringRef)kAutoFillDarwinNotificationIdentifier;
    CFNotificationCenterAddObserver(center,
                                    (__bridge const void *)(self),
                                    wormholeNotificationCallback,
                                    str,
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
}

+ (void)unregisterForNotifications {
    CFNotificationCenterRef const center = CFNotificationCenterGetDarwinNotifyCenter();
    CFStringRef str = (__bridge CFStringRef)kAutoFillDarwinNotificationIdentifier;
    CFNotificationCenterRemoveObserver(center,
                                       (__bridge const void *)(self),
                                       str,
                                       NULL);
}

void wormholeNotificationCallback(CFNotificationCenterRef center,
                                  void * observer,
                                  CFStringRef name,
                                  void const * object,
                                  CFDictionaryRef userInfo) {

    NSObject *sender = (__bridge NSObject *)(observer);











    
    slog(@"🟢 Got Darwin Notification object = [%@], sender = [%@]", object, sender);
    
    completionBlock();
}

@end
