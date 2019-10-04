//
//  DebugHelper.m
//  Strongbox-iOS
//
//  Created by Mark on 01/10/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "DebugHelper.h"
#import "SafesList.h"
#import "Settings.h"
#import "Utils.h"

@implementation DebugHelper

+ (NSString*)getAboutDebugString {
    int i=0;
    NSString *safesMessage = @"Databases Collection\n----------------\n";
    for(SafeMetaData *safe in [SafesList sharedInstance].snapshot) {
        NSString *thisSafe = [NSString stringWithFormat:@"%d. [%@]\n   [%@]-[%@]-[%d%d%d%d%d]\n", i++,
                              safe.nickName,
                              safe.fileName,
                              safe.fileIdentifier,
                              safe.storageProvider,
                              safe.isTouchIdEnabled,
                              safe.isEnrolledForConvenience,
                              safe.offlineCacheEnabled,
                              safe.offlineCacheAvailable];
        
        safesMessage = [safesMessage stringByAppendingString:thisSafe];
    }
    safesMessage = [safesMessage stringByAppendingString:@"----------------"];

    NSString* model = [[UIDevice currentDevice] model];
    NSString* systemName = [[UIDevice currentDevice] systemName];
    NSString* systemVersion = [[UIDevice currentDevice] systemVersion];
    NSString* pro = [[Settings sharedInstance] isPro] ? @"P" : @"";
    NSString* isFreeTrial = [[Settings sharedInstance] isFreeTrial] ? @"F" : @"";
    long epoch = (long)Settings.sharedInstance.installDate.timeIntervalSince1970;

    NSString* message = [NSString stringWithFormat:
                         @"%@\n"
                         @"Model: %@\n"
                         @"System Name: %@\n"
                         @"System Version: %@\n"
                         @"Ep: %ld\n"
                         @"Flags: %@%@%@\n"
                         @"Bundle: %@",
                         safesMessage,
                         model,
                         systemName,
                         systemVersion,
                         epoch,
                         pro,
                         isFreeTrial,
                         [Settings.sharedInstance getFlagsStringForDiagnostics],
                         [Utils getAppBundleId]];
    
    return message;
}

+ (NSString*)getSupportEmailDebugString {
    int i=0;
    NSString *safesMessage = @"Databases Collection<br />----------------<br />";
    for(SafeMetaData *safe in [SafesList sharedInstance].snapshot) {
        NSString *thisSafe = [NSString stringWithFormat:@"%d. [%@]<br />   [%@]-[%@]-[%d%d%d%d%d]<br />", i++,
                              safe.nickName,
                              safe.fileName,
                              safe.fileIdentifier,
                              safe.storageProvider,
                              safe.isTouchIdEnabled,
                              safe.isEnrolledForConvenience,
                              safe.offlineCacheEnabled,
                              safe.offlineCacheAvailable];
        
        safesMessage = [safesMessage stringByAppendingString:thisSafe];
    }
    safesMessage = [safesMessage stringByAppendingString:@"----------------"];

    NSString* model = [[UIDevice currentDevice] model];
    NSString* systemName = [[UIDevice currentDevice] systemName];
    NSString* systemVersion = [[UIDevice currentDevice] systemVersion];
    NSString* pro = [[Settings sharedInstance] isPro] ? @"P" : @"";
    NSString* isFreeTrial = [[Settings sharedInstance] isFreeTrial] ? @"F" : @"";
    long epoch = (long)Settings.sharedInstance.installDate.timeIntervalSince1970;

    NSString* message = [NSString stringWithFormat:@"I'm having some trouble with Strongbox... <br /><br />"
                         @"Please include as much detail as possible and screenshots if appropriate...<br /><br />"
                         @"Here is some debug information which might help:<br />"
                         @"%@<br />"
                         @"Model: %@<br />"
                         @"System Name: %@<br />"
                         @"System Version: %@<br />"
                         @"Ep: %ld<br />"
                         @"Bundle: %@<br />"
                         @"Flags: %@%@%@", safesMessage, model, systemName, systemVersion, epoch, [Utils getAppBundleId], pro, isFreeTrial,
                         [Settings.sharedInstance getFlagsStringForDiagnostics]];
    
    return message;
}

@end
