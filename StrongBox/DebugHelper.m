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

@implementation DebugHelper

+ (NSString*)getAboutDebugString {
//    int i=0;
    NSString *safesMessage = @"Databases Collection\n----------------\n";
    for(SafeMetaData *safe in [SafesList sharedInstance].snapshot) {
        NSDictionary* jsonDict = [safe getJsonSerializationDictionary];
        NSString *thisSafe = [jsonDict description];
        
        //
        
//        NSString *thisSafe = [NSString stringWithFormat:@"%d. [%@]\n   [%@]-[%@]-[%lu%d%d]\n", i++,
//                              safe.nickName,
//                              safe.fileName,
//                              safe.fileIdentifier,
//                              (unsigned long)safe.storageProvider,
//                              safe.isTouchIdEnabled,
//                              safe.isEnrolledForConvenience];
//        
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
    
    NSString* message = [NSString stringWithFormat:
                         @"%@\n"
                         @"Model: %@\n"
                         @"System Name: %@\n"
                         @"System Version: %@\n"
                         @"Ep: %ld\n"
                         @"Flags: %@%@%@\n"
                         @"App Version: %@ [%@ (%@)@%@]\n"
                         @"JSON Crash:\n%@",
                         safesMessage,
                         model,
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
                         jsonCrash];

    return message;
}

+ (NSString*)getSupportEmailDebugString {
//    int i=0;
    NSString *safesMessage = @"Databases Collection<br />----------------<br />";
    for(SafeMetaData *safe in [SafesList sharedInstance].snapshot) {
        NSDictionary* jsonDict = [safe getJsonSerializationDictionary];
        NSString *thisSafe = [jsonDict description];
//        [NSString stringWithFormat:@"%d. [%@]<br />   [%@]-[%@]-[%lu%d%d]<br />", i++,
//                              safe.nickName,
//                              safe.fileName,
//                              safe.fileIdentifier,
//                              (unsigned long)safe.storageProvider,
//                              safe.isTouchIdEnabled,
//                              json];
//
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
    
    NSString* message = [NSString stringWithFormat:@"I'm having some trouble with Strongbox... <br /><br />"
                         @"Please include as much detail as possible and screenshots if appropriate...<br /><br />"
                         @"Here is some debug information which might help:<br />"
                         @"%@<br />"
                         @"Model: %@<br />"
                         @"System Name: %@<br />"
                         @"System Version: %@<br />"
                         @"Ep: %ld<br />"
                         @"App Version: %@ [%@ (%@)@%@]<br />"
                         @"Flags: %@%@%@<br />"
                         @"JSON Crash:<br />%@",
                         safesMessage,
                         model,
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
                         jsonCrash];
    
    return message;
}

@end
