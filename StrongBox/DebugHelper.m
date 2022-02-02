//
//  DebugHelper.m
//  Strongbox-iOS
//
//  Created by Mark on 01/10/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "DebugHelper.h"
#import "Utils.h"
#import "FileManager.h"
#import <mach-o/arch.h>
#import "NSDate+Extensions.h"
#import "NSArray+Extensions.h"
#import "SafeStorageProviderFactory.h"
#import "WorkingCopyManager.h"

#if TARGET_OS_IPHONE

#import "DatabasePreferences.h"
#import "AppPreferences.h"
#import "git-version.h"
#import "SyncManager.h"

#else

#import <objc/message.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/sysctl.h>
#import "Settings.h"
#import "MacSyncManager.h"
#import "FileManager.h"
#import "MacDatabasePreferences.h"

#endif

@implementation DebugHelper

+ (NSString*)getAboutDebugString {
    NSArray* lines = [self getDebugLines];
    return [lines componentsJoinedByString:@"\n"];
}

+ (NSString*)getCrashEmailDebugString {
    NSArray* lines = [self getDebugLines];
    return [lines componentsJoinedByString:@"\n"];
}

#if !TARGET_OS_IPHONE

static NSString *ModelIdentifier()
{
    NSString *result=@"Unknown Mac";
    size_t len=0;
    sysctlbyname("hw.model", NULL, &len, NULL, 0);
    if (len) {
        NSMutableData *data=[NSMutableData dataWithLength:len];
        sysctlbyname("hw.model", [data mutableBytes], &len, NULL, 0);
        result=[NSString stringWithUTF8String:[data bytes]];
    }
    return result;
}


+ (NSString *)systemVersion {
    static NSString *systemVersion = nil;

    if (!systemVersion) {
        if ( [NSProcessInfo.processInfo respondsToSelector:@selector(operatingSystemVersionString)] ) {
            systemVersion = NSProcessInfo.processInfo.operatingSystemVersionString;
        }
        else {
            systemVersion = @"<Unknown>";
        }
    }

    return systemVersion;
}

#endif

+ (NSArray<NSString*>*)getDebugLines {
    NSMutableArray<NSString*>* debugLines = [NSMutableArray array];
    
    [debugLines addObject:[NSString stringWithFormat:@"Strongbox %@ Debug Information at %@", [Utils getAppVersion], NSDate.date.friendlyDateTimeStringBothPrecise]];
    [debugLines addObject:@"--------------------"];
    
    

#if TARGET_OS_IPHONE
    [debugLines addObject:[NSString stringWithFormat:@"App Version: %@ [%@ (%@)@%@]", [Utils getAppBundleId], [Utils getAppVersion], [Utils getAppBuildNumber], GIT_SHA_VERSION]];
#else
    [debugLines addObject:[NSString stringWithFormat:@"App Version: %@ [%@ (%@)]", [Utils getAppBundleId], [Utils getAppVersion], [Utils getAppBuildNumber]]];
#endif
    

    [debugLines addObject:@"--------------------"];
    [debugLines addObject:@"Device"];
    [debugLines addObject:@"--------------------"];

#if TARGET_OS_IPHONE
    NSString* model = [[UIDevice currentDevice] model];
    NSString* systemName = [[UIDevice currentDevice] systemName];
    NSString* systemVersion = [[UIDevice currentDevice] systemVersion];
#else
    NSString* model = ModelIdentifier();
    NSString* systemName = @"MacOS";
    NSString* systemVersion = [DebugHelper systemVersion];
#endif
    const NXArchInfo *info = NXGetLocalArchInfo();
    NSString *typeOfCpu = info ? [NSString stringWithUTF8String:info->description] : @"Unknown";

    [debugLines addObject:[NSString stringWithFormat:@"Model: %@", model]];
    [debugLines addObject:[NSString stringWithFormat:@"CPU: %@", typeOfCpu]];
    [debugLines addObject:[NSString stringWithFormat:@"System Name: %@", systemName]];
    [debugLines addObject:[NSString stringWithFormat:@"System Version: %@", systemVersion]];

    

    [debugLines addObject:@"--------------------"];
    [debugLines addObject:@"Preferences"];
    [debugLines addObject:@"--------------------"];

#if TARGET_OS_IPHONE
    NSUserDefaults *defs = AppPreferences.sharedInstance.sharedAppGroupDefaults;
    NSDictionary* prefs = [defs persistentDomainForName:AppPreferences.sharedInstance.appGroupName];
#else
    NSUserDefaults *defs = Settings.sharedInstance.sharedAppGroupDefaults;
    NSDictionary* prefs = [defs persistentDomainForName:Settings.sharedInstance.appGroupName];
#endif
    
    for (NSString* pref in prefs) {
        if ( ![pref hasPrefix:@"com.apple"] &&
            ![pref hasPrefix:@"Apple"] &&
            ![pref hasPrefix:@"appLockPin"] &&
            ![pref hasPrefix:@"NS"] &&
            ![pref hasPrefix:@"searchFieldRecents"] &&
            ![pref hasPrefix:@"passwordGenerationConfig"] &&
            ![pref hasPrefix:@"passwordGenerationSettings"] &&
            ![pref hasPrefix:@"autoFillNewRecordSettings"] ) {
            [debugLines addObject:[NSString stringWithFormat:@"%@: %@", pref, [defs valueForKey:pref]]];
        }
    }

#if TARGET_OS_IPHONE
    NSString* pro = [[AppPreferences sharedInstance] isPro] ? @"P" : @"";
    NSString* isFreeTrial = [[AppPreferences sharedInstance] isFreeTrial] ? @"F" : @"";
    long epoch = (long)AppPreferences.sharedInstance.installDate.timeIntervalSince1970;
    [debugLines addObject:[NSString stringWithFormat:@"Ep: %ld", epoch]];
    [debugLines addObject:[NSString stringWithFormat:@"Flags: %@%@%@", pro, isFreeTrial, [AppPreferences.sharedInstance getFlagsStringForDiagnostics]]];

    
    

    [debugLines addObject:@"--------------------"];
    [debugLines addObject:@"Last Crash"];
    [debugLines addObject:@"--------------------"];

    if ([NSFileManager.defaultManager fileExistsAtPath:FileManager.sharedInstance.archivedCrashFile.path]) {
        NSData* crashFileData = [NSData dataWithContentsOfURL:FileManager.sharedInstance.archivedCrashFile];
        NSString* jsonCrash = [[NSString alloc] initWithData:crashFileData encoding:NSUTF8StringEncoding];
        [debugLines addObject:[NSString stringWithFormat:@"JSON Crash:%@", jsonCrash]];
    }
#endif
    
    [debugLines addObject:@"--------------------"];
    [debugLines addObject:@"Sync"];
    [debugLines addObject:@"--------------------"];

#if TARGET_OS_IPHONE
    for(DatabasePreferences *safe in DatabasePreferences.allDatabases) {
        SyncStatus *syncStatus = [SyncManager.sharedInstance getSyncStatus:safe];
#else
    for(MacDatabasePreferences *safe in MacDatabasePreferences.allDatabases ) {
        SyncStatus *syncStatus = [MacSyncManager.sharedInstance getSyncStatus:safe];
#endif
        NSMutableArray<NSArray*>* mutableSyncs = NSMutableArray.array;
        NSMutableSet<NSUUID*>* set = NSMutableSet.set;
        NSMutableArray *currentSync;
        for (SyncStatusLogEntry* entry in syncStatus.changeLog) {
            if (![set containsObject:entry.syncId]) {
                currentSync = NSMutableArray.array;
                [mutableSyncs addObject:currentSync];
                [set addObject:entry.syncId];
            }
            
            [currentSync addObject:entry];
        }
        
        NSArray<NSArray<SyncStatusLogEntry*>*> *syncs = [[mutableSyncs reverseObjectEnumerator] allObjects];
        
        
        
        NSArray* failedSyncs = [syncs filter:^BOOL(NSArray<SyncStatusLogEntry *> * _Nonnull sync) {
            return [sync anyMatch:^BOOL(SyncStatusLogEntry * _Nonnull status) {
                return status.state == kSyncOperationStateError;
            }];
        }];
        

        NSString* spName = [SafeStorageProviderFactory getStorageDisplayName:safe];
        
        for (NSArray* failed in failedSyncs) {
            [debugLines addObject:[NSString stringWithFormat:@"============== [%@] Failed Sync to [%@] ===============", safe.nickName, spName]];
            [debugLines addObjectsFromArray:failed];
            [debugLines addObject:@"=========================================="];
        }
        
        
        
        NSDate* mod;
        unsigned long long fileSize;
        NSURL* url = [WorkingCopyManager.sharedInstance getLocalWorkingCache:safe.uuid modified:&mod fileSize:&fileSize];
        
        NSString* syncState;
        if (url) {
            syncState = [NSString stringWithFormat:@"%@ (%@ Sync) => %@ (%@)", safe.nickName, spName, mod.friendlyDateTimeStringBothPrecise, friendlyFileSizeString(fileSize)];
        }
        else {
            syncState = [NSString stringWithFormat:@"%@ (%@ Sync) => Unknown", safe.nickName, spName];
        }
        
        [debugLines addObject:syncState];
    }

    [debugLines addObject:@"--------------------"];

    

#if TARGET_OS_IPHONE
    [debugLines addObjectsFromArray:[DebugHelper listDirectoryRecursive:FileManager.sharedInstance.appSupportDirectory]];
    [debugLines addObjectsFromArray:[DebugHelper listDirectoryRecursive:FileManager.sharedInstance.documentsDirectory]];


#endif
        
    [debugLines addObjectsFromArray:[DebugHelper listDirectoryRecursive:FileManager.sharedInstance.sharedAppGroupDirectory]];

    

    [debugLines addObject:@"--------------------"];

        
#if TARGET_OS_IPHONE
    for(DatabasePreferences *safe in DatabasePreferences.allDatabases) {
        NSString* spName = [SafeStorageProviderFactory getStorageDisplayName:safe];
        [debugLines addObject:@"================================================================="];
        [debugLines addObject:[NSString stringWithFormat:@"[%@] on [%@] Config", safe.nickName, spName]];
        [debugLines addObject:@"================================================================="];

        NSMutableDictionary* jsonDict = [safe getJsonSerializationDictionary].mutableCopy;
        jsonDict[@"keyFileBookmark"] = jsonDict[@"keyFileBookmark"] ? @"<redacted>" : @"<Not Set>";
        NSString *thisSafe = [jsonDict description];
        [debugLines addObject:thisSafe];
    }
#else
    for(MacDatabasePreferences *safe in MacDatabasePreferences.allDatabases ) {
        NSString* spName = [SafeStorageProviderFactory getStorageDisplayName:safe];
        [debugLines addObject:@"================================================================="];
        [debugLines addObject:[NSString stringWithFormat:@"[%@] on [%@] Config", safe.nickName, spName]];
        [debugLines addObject:@"================================================================="];

        NSMutableDictionary<NSString*, NSString*>* mut = safe.debugInfoLines.mutableCopy;
        
        [mut removeObjectForKey:@"_storageInfo"]; 
        
        for ( NSString* key in mut.allKeys ) {
            NSString* val = mut[key];
            [debugLines addObject:[NSString stringWithFormat:@"%@ = %@", key, val]];
        }
        
        [debugLines addObject:@"================================================================="];
    }
#endif

    [debugLines addObject:@"--------------------"];
    
    return debugLines;
}

+ (NSArray<NSString*>*)listDirectoryRecursive:(NSURL*)URL {
    return [DebugHelper listDirectoryRecursive:URL listRelativeToURL:URL];
}

+ (NSArray<NSString*>*)listDirectoryRecursive:(NSURL*)URL listRelativeToURL:(NSURL*)listRelativeToURL {
    NSMutableArray<NSString*>* ret = [NSMutableArray array];
        
    NSArray<NSURL*>* contents = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:URL
                                                              includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                                                               options:kNilOptions
                                                                                                 error:NULL];
    
    for (NSURL *file in contents) {
        NSString* relativePath = file.path.length > listRelativeToURL.path.length ? [file.path substringFromIndex:listRelativeToURL.path.length + 1] : file.path;

        NSError *error;
        NSNumber *isDirectory = nil;

        if (![file getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
            [ret addObject:[NSString stringWithFormat:@"Error %@", file]];
        }
        else {
            if (![isDirectory boolValue]) {
                NSDictionary* attributes = [NSFileManager.defaultManager attributesOfItemAtPath:file.path error:&error];
                
                if (error) {
                    [ret addObject:[NSString stringWithFormat:@"%@ - %@", relativePath, error]];
                }
                else {
                    [ret addObject:[NSString stringWithFormat:@"[%@] %@ - %@", relativePath, friendlyFileSizeString(attributes.fileSize), attributes.fileModificationDate.friendlyDateTimeStringPrecise]];
                }
            }
            else{

                NSArray* subdir = [self listDirectoryRecursive:file listRelativeToURL:listRelativeToURL];
                [ret addObjectsFromArray:subdir];
            }
        }
    }
    
    return ret;
}

@end
