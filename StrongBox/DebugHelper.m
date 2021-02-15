//
//  DebugHelper.m
//  Strongbox-iOS
//
//  Created by Mark on 01/10/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
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
#import "NSArray+Extensions.h"
#import "SafeStorageProviderFactory.h"
#import "WorkingCopyManager.h"

@implementation DebugHelper

+ (NSString*)getAboutDebugString {
    NSArray* lines = [self getDebugLines];
    return [lines componentsJoinedByString:@"\n"];
}

+ (NSString*)getCrashEmailDebugString {
    NSArray* lines = [self getDebugLines];
    return [lines componentsJoinedByString:@"\n"];
}

+ (NSArray<NSString*>*)getDebugLines {
    NSMutableArray<NSString*>* debugLines = [NSMutableArray array];
    
    [debugLines addObject:[NSString stringWithFormat:@"Strongbox Debug Information at %@", NSDate.date.friendlyDateTimeStringBothPrecise]];
    [debugLines addObject:@"--------------------"];

    
    
    NSString* model = [[UIDevice currentDevice] model];
    NSString* systemName = [[UIDevice currentDevice] systemName];
    NSString* systemVersion = [[UIDevice currentDevice] systemVersion];
    NSString* pro = [[SharedAppAndAutoFillSettings sharedInstance] isPro] ? @"P" : @"";
    NSString* isFreeTrial = [[SharedAppAndAutoFillSettings sharedInstance] isFreeTrial] ? @"F" : @"";
    long epoch = (long)Settings.sharedInstance.installDate.timeIntervalSince1970;

    const NXArchInfo *info = NXGetLocalArchInfo();
    NSString *typeOfCpu = info ? [NSString stringWithUTF8String:info->description] : @"Unknown";

    [debugLines addObject:[NSString stringWithFormat:@"Model: %@", model]];
    [debugLines addObject:[NSString stringWithFormat:@"CPU: %@", typeOfCpu]];
    [debugLines addObject:[NSString stringWithFormat:@"System Name: %@", systemName]];
    [debugLines addObject:[NSString stringWithFormat:@"System Version: %@", systemVersion]];
    [debugLines addObject:[NSString stringWithFormat:@"Ep: %ld", epoch]];
    [debugLines addObject:[NSString stringWithFormat:@"Flags: %@%@%@", pro, isFreeTrial, [Settings.sharedInstance getFlagsStringForDiagnostics]]];
    [debugLines addObject:[NSString stringWithFormat:@"App Version: %@ [%@ (%@)@%@]", [Utils getAppBundleId], [Utils getAppVersion], [Utils getAppBuildNumber], GIT_SHA_VERSION]];

    if ([NSFileManager.defaultManager fileExistsAtPath:FileManager.sharedInstance.archivedCrashFile.path]) {
        NSData* crashFileData = [NSData dataWithContentsOfURL:FileManager.sharedInstance.archivedCrashFile];
        NSString* jsonCrash = [[NSString alloc] initWithData:crashFileData encoding:NSUTF8StringEncoding];
        [debugLines addObject:[NSString stringWithFormat:@"JSON Crash:%@", jsonCrash]];
    }

    [debugLines addObject:@"--------------------"];

    for(SafeMetaData *safe in [SafesList sharedInstance].snapshot) {
        SyncStatus *syncStatus = [SyncManager.sharedInstance getSyncStatus:safe];

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
        NSURL* url = [WorkingCopyManager.sharedInstance getLocalWorkingCache:safe modified:&mod fileSize:&fileSize];
        
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

    
    
    [debugLines addObjectsFromArray:[DebugHelper listDirectoryRecursive:FileManager.sharedInstance.appSupportDirectory]];
    [debugLines addObjectsFromArray:[DebugHelper listDirectoryRecursive:FileManager.sharedInstance.documentsDirectory]];
    [debugLines addObjectsFromArray:[DebugHelper listDirectoryRecursive:FileManager.sharedInstance.sharedAppGroupDirectory]];
    [debugLines addObjectsFromArray:[DebugHelper listDirectoryRecursive:[NSURL fileURLWithPath:FileManager.sharedInstance.tmpEncryptedAttachmentPath isDirectory:YES]]];
    [debugLines addObjectsFromArray:[DebugHelper listDirectoryRecursive:[NSURL fileURLWithPath:FileManager.sharedInstance.tmpAttachmentPreviewPath isDirectory:YES]]];

    

    [debugLines addObject:@"--------------------"];

    for(SafeMetaData *safe in [SafesList sharedInstance].snapshot) {
        NSString* spName = [SafeStorageProviderFactory getStorageDisplayName:safe];
        [debugLines addObject:[NSString stringWithFormat:@"[%@] on [%@] Config", safe.nickName, spName]];

        NSMutableDictionary* jsonDict = [safe getJsonSerializationDictionary].mutableCopy;
        jsonDict[@"keyFileBookmark"] = jsonDict[@"keyFileBookmark"] ? @"<redacted>" : @"<Not Set>";
        NSString *thisSafe = [jsonDict description];
        [debugLines addObject:thisSafe];
    }

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
