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
#import "SharedAppAndAutoFillSettings.h"
#import "Utils.h"
#import "git-version.h"
#import "FileManager.h"
#import <mach-o/arch.h>
#import "SyncManager.h"
#import "NSDate+Extensions.h"

@implementation DebugHelper

+ (NSString*)getAboutDebugString {
    NSString *safesMessage = @"Databases Collection\n----------------\n";

    for(SafeMetaData *safe in [SafesList sharedInstance].snapshot) {
        NSDate* mod;
        unsigned long long fileSize;
        
        NSURL* url = [SyncManager.sharedInstance getLocalWorkingCache:safe modified:&mod fileSize:&fileSize];
        
        NSString* syncState;
        if (url) {
            syncState = [NSString stringWithFormat:@"%@ (Sync) => %@ (%@)\n", safe.nickName, mod.friendlyDateTimeStringBothPrecise, friendlyFileSizeString(fileSize)];
        }
        else {
            syncState = [NSString stringWithFormat:@"%@ (Sync) => Unknown\n", safe.nickName];
        }
        
        safesMessage = [safesMessage stringByAppendingString:syncState];
    }
    
    for(SafeMetaData *safe in [SafesList sharedInstance].snapshot) {
        NSMutableDictionary* jsonDict = [safe getJsonSerializationDictionary].mutableCopy;
        jsonDict[@"keyFileBookmark"] = jsonDict[@"keyFileBookmark"] ? @"<redacted>" : @"<Not Set>";
        NSString *thisSafe = [jsonDict description];
        safesMessage = [safesMessage stringByAppendingString:thisSafe];
    }
    safesMessage = [safesMessage stringByAppendingString:@"----------------"];

    NSString* model = [[UIDevice currentDevice] model];
    NSString* systemName = [[UIDevice currentDevice] systemName];
    NSString* systemVersion = [[UIDevice currentDevice] systemVersion];
    NSString* pro = [[SharedAppAndAutoFillSettings sharedInstance] isPro] ? @"P" : @"";
    NSString* isFreeTrial = [[SharedAppAndAutoFillSettings sharedInstance] isFreeTrial] ? @"F" : @"";
    long epoch = (long)Settings.sharedInstance.installDate.timeIntervalSince1970;

    NSString* jsonCrash = @"";
    if ([NSFileManager.defaultManager fileExistsAtPath:FileManager.sharedInstance.archivedCrashFile.path]) {
        NSData* crashFileData = [NSData dataWithContentsOfURL:FileManager.sharedInstance.archivedCrashFile];
        jsonCrash = [[NSString alloc] initWithData:crashFileData encoding:NSUTF8StringEncoding];
    }

    const NXArchInfo *info = NXGetLocalArchInfo();
    NSString *typeOfCpu = info ? [NSString stringWithUTF8String:info->description] : @"Unknown";

    NSString* message = [NSString stringWithFormat:
                         @"Model: %@\n"
                         @"CPU: %@\n"
                         @"System Name: %@\n"
                         @"System Version: %@\n"
                         @"Ep: %ld\n"
                         @"Flags: %@%@%@\n"
                         @"App Version: %@ [%@ (%@)@%@]\n"
                         @"JSON Crash:\n%@"
                         @"%@\n",
                         model,
                         typeOfCpu,
                         systemName,
                         systemVersion,
                         epoch,
                         pro,
                         isFreeTrial,
                         [Settings.sharedInstance getFlagsStringForDiagnostics],
                         [Utils getAppBundleId],
                         [Utils getAppVersion],
                         [Utils getAppBuildNumber],
                         GIT_SHA_VERSION,
                         jsonCrash,
                         safesMessage];

    return message;
}

+ (NSString*)getSupportEmailDebugString {
    NSString *safesMessage = @"Databases Collection<br />----------------<br />";
    
    for(SafeMetaData *safe in [SafesList sharedInstance].snapshot) {
        NSDate* mod;
        unsigned long long fileSize;
        
        NSURL* url = [SyncManager.sharedInstance getLocalWorkingCache:safe modified:&mod fileSize:&fileSize];
        
        NSString* syncState;
        if (url) {
            syncState = [NSString stringWithFormat:@"%@ (Sync) => %@ (%@)<br />", safe.nickName, mod.friendlyDateTimeStringBothPrecise, friendlyFileSizeString(fileSize)];
        }
        else {
            syncState = [NSString stringWithFormat:@"%@ (Sync) => Unknown<br />", safe.nickName];
        }
        
        safesMessage = [safesMessage stringByAppendingString:syncState];
    }
    
    for(SafeMetaData *safe in [SafesList sharedInstance].snapshot) {
        NSMutableDictionary* jsonDict = [safe getJsonSerializationDictionary].mutableCopy;
        jsonDict[@"keyFileBookmark"] = jsonDict[@"keyFileBookmark"] ? @"<redacted>" : @"<Not Set>";
        NSString *thisSafe = [jsonDict description];
        safesMessage = [safesMessage stringByAppendingString:thisSafe];
    }
    
    safesMessage = [safesMessage stringByAppendingString:@"----------------"];

    NSString* model = [[UIDevice currentDevice] model];
    NSString* systemName = [[UIDevice currentDevice] systemName];
    NSString* systemVersion = [[UIDevice currentDevice] systemVersion];
    NSString* pro = [[SharedAppAndAutoFillSettings sharedInstance] isPro] ? @"P" : @"";
    NSString* isFreeTrial = [[SharedAppAndAutoFillSettings sharedInstance] isFreeTrial] ? @"F" : @"";
    long epoch = (long)Settings.sharedInstance.installDate.timeIntervalSince1970;

    NSString* jsonCrash = @"{}";
    if ([NSFileManager.defaultManager fileExistsAtPath:FileManager.sharedInstance.archivedCrashFile.path]) {
        NSData* crashFileData = [NSData dataWithContentsOfURL:FileManager.sharedInstance.archivedCrashFile];
        jsonCrash = [[NSString alloc] initWithData:crashFileData encoding:NSUTF8StringEncoding];
    }
    
    const NXArchInfo *info = NXGetLocalArchInfo();
    NSString *typeOfCpu = info ? [NSString stringWithUTF8String:info->description] : @"Unknown";

    NSString* message = [NSString stringWithFormat:@"I'm having some trouble with Strongbox... <br /><br />"
                         @"Please include as much detail as possible and screenshots if appropriate...<br /><br />"
                         @"Here is some debug information which might help:<br />"
                         @"Model: %@<br />"
                         @"CPU: %@<br />"
                         @"System Name: %@<br />"
                         @"System Version: %@<br />"
                         @"Ep: %ld<br />"
                         @"App Version: %@ [%@ (%@)@%@]<br />"
                         @"Flags: %@%@%@<br />"
                         @"JSON Crash:<br />%@"
                         @"%@<br />",
                         model,
                         typeOfCpu,
                         systemName,
                         systemVersion,
                         epoch,
                         [Utils getAppBundleId],
                         [Utils getAppVersion],
                         [Utils getAppBuildNumber],
                         GIT_SHA_VERSION,
                         pro,
                         isFreeTrial,
                         [Settings.sharedInstance getFlagsStringForDiagnostics],
                         jsonCrash,
                         safesMessage];
    
    return message;
}

+ (NSString*)getCrashEmailDebugString {
    NSString *safesMessage = @"Databases Collection\n----------------\n";
    
    for(SafeMetaData *safe in [SafesList sharedInstance].snapshot) {
        NSDate* mod;
        unsigned long long fileSize;
        
        NSURL* url = [SyncManager.sharedInstance getLocalWorkingCache:safe modified:&mod fileSize:&fileSize];
        
        NSString* syncState;
        if (url) {
            syncState = [NSString stringWithFormat:@"%@ (Sync) => %@ (%@)\n", safe.nickName, mod.friendlyDateTimeStringBothPrecise, friendlyFileSizeString(fileSize)];
        }
        else {
            syncState = [NSString stringWithFormat:@"%@ (Sync) => Unknown\n", safe.nickName];
        }
        
        safesMessage = [safesMessage stringByAppendingString:syncState];
    }

    for(SafeMetaData *safe in [SafesList sharedInstance].snapshot) {
        NSMutableDictionary* jsonDict = [safe getJsonSerializationDictionary].mutableCopy;
        jsonDict[@"keyFileBookmark"] = jsonDict[@"keyFileBookmark"] ? @"<redacted>" : @"<Not Set>";
        NSString *thisSafe = [jsonDict description];
        safesMessage = [safesMessage stringByAppendingString:thisSafe];
    }
    
    safesMessage = [safesMessage stringByAppendingString:@"----------------"];

    NSString* model = [[UIDevice currentDevice] model];
    NSString* systemName = [[UIDevice currentDevice] systemName];
    NSString* systemVersion = [[UIDevice currentDevice] systemVersion];
    NSString* pro = [[SharedAppAndAutoFillSettings sharedInstance] isPro] ? @"P" : @"";
    NSString* isFreeTrial = [[SharedAppAndAutoFillSettings sharedInstance] isFreeTrial] ? @"F" : @"";
    long epoch = (long)Settings.sharedInstance.installDate.timeIntervalSince1970;

    NSString* jsonCrash = @"{}";
    if ([NSFileManager.defaultManager fileExistsAtPath:FileManager.sharedInstance.archivedCrashFile.path]) {
        NSData* crashFileData = [NSData dataWithContentsOfURL:FileManager.sharedInstance.archivedCrashFile];
        jsonCrash = [[NSString alloc] initWithData:crashFileData encoding:NSUTF8StringEncoding];
    }
    
    const NXArchInfo *info = NXGetLocalArchInfo();
    NSString *typeOfCpu = info ? [NSString stringWithUTF8String:info->description] : @"Unknown";
    
    NSString* message = [NSString stringWithFormat:
                         @"Model: %@\n"
                         @"CPU: %@\n"
                         @"System Name: %@\n"
                         @"System Version: %@\n"
                         @"Ep: %ld\n"
                         @"App Version: %@ [%@ (%@)@%@]\n"
                         @"Flags: %@%@%@\n"
                         @"JSON Crash:\n%@"
                         @"%@\n",
                         model,
                         typeOfCpu,
                         systemName,
                         systemVersion,
                         epoch,
                         [Utils getAppBundleId],
                         [Utils getAppVersion],
                         [Utils getAppBuildNumber],
                         GIT_SHA_VERSION,
                         pro,
                         isFreeTrial,
                         [Settings.sharedInstance getFlagsStringForDiagnostics],
                         jsonCrash,
                         safesMessage];
    
    return message;
}



@end
