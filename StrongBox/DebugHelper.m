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

#import "SafesList.h"
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
#import "DatabasesManager.h"
#import "MacSyncManager.h"
#import "FileManager.h"

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


+ (NSString *)systemVersion
{
  static NSString *systemVersion = nil;

  if (!systemVersion) {
    typedef struct {
      NSInteger majorVersion;
      NSInteger minorVersion;
      NSInteger patchVersion;
    } MyOperatingSystemVersion;

    if ([[NSProcessInfo processInfo] respondsToSelector:@selector(operatingSystemVersion)]) {
      MyOperatingSystemVersion version = ((MyOperatingSystemVersion(*)(id, SEL))objc_msgSend_stret)([NSProcessInfo processInfo], @selector(operatingSystemVersion));
      systemVersion = [NSString stringWithFormat:@"%ld.%ld.%ld", (long)version.majorVersion, version.minorVersion, version.patchVersion];
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
            ![pref hasPrefix:@"appLockPin2"] &&
            ![pref hasPrefix:@"NS"] &&
            ![pref hasPrefix:@"searchFieldRecents"]) {
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
    for(SafeMetaData *safe in [SafesList sharedInstance].snapshot) {
        SyncStatus *syncStatus = [SyncManager.sharedInstance getSyncStatus:safe];
#else
    for(DatabaseMetadata *safe in [DatabasesManager sharedInstance].snapshot) {
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

    

#if TARGET_OS_IPHONE
    [debugLines addObjectsFromArray:[DebugHelper listDirectoryRecursive:FileManager.sharedInstance.appSupportDirectory]];
    [debugLines addObjectsFromArray:[DebugHelper listDirectoryRecursive:FileManager.sharedInstance.documentsDirectory]];
    [debugLines addObjectsFromArray:[DebugHelper listDirectoryRecursive:[NSURL fileURLWithPath:FileManager.sharedInstance.tmpEncryptedAttachmentPath isDirectory:YES]]];
    [debugLines addObjectsFromArray:[DebugHelper listDirectoryRecursive:[NSURL fileURLWithPath:FileManager.sharedInstance.tmpAttachmentPreviewPath isDirectory:YES]]];
#endif

    [debugLines addObjectsFromArray:[DebugHelper listDirectoryRecursive:FileManager.sharedInstance.sharedAppGroupDirectory]];

    

    [debugLines addObject:@"--------------------"];

        
#if TARGET_OS_IPHONE
    for(SafeMetaData *safe in [SafesList sharedInstance].snapshot) {
        NSString* spName = [SafeStorageProviderFactory getStorageDisplayName:safe];
        [debugLines addObject:[NSString stringWithFormat:@"[%@] on [%@] Config", safe.nickName, spName]];

        NSMutableDictionary* jsonDict = [safe getJsonSerializationDictionary].mutableCopy;
        jsonDict[@"keyFileBookmark"] = jsonDict[@"keyFileBookmark"] ? @"<redacted>" : @"<Not Set>";
        NSString *thisSafe = [jsonDict description];
        [debugLines addObject:thisSafe];
    }
#else
    for(DatabaseMetadata *safe in [DatabasesManager sharedInstance].snapshot) {
        NSString* spName = [SafeStorageProviderFactory getStorageDisplayName:safe];
        [debugLines addObject:[NSString stringWithFormat:@"[%@] on [%@] Config", safe.nickName, spName]];

        @autoreleasepool {
            unsigned int count;
            Ivar *ivars = class_copyIvarList([DatabaseMetadata class], &count);
            for (unsigned int i = 0; i < count; i++) {
                Ivar ivar = ivars[i];

                const char *name = ivar_getName(ivar);
                const char *type = ivar_getTypeEncoding(ivar);
                ptrdiff_t offset = ivar_getOffset(ivar);

                NSString* str;
                if (strncmp(type, "i", 1) == 0) {
                    int intValue = *(int*)((uintptr_t)safe + offset);
                    str = [NSString stringWithFormat:@"%s = %i", name, intValue];
                }
                else if (strncmp(type, "f", 1) == 0) {
                    float floatValue = *(float*)((uintptr_t)safe + offset);
                    str = [NSString stringWithFormat:@"%s = %f", name, floatValue];
                }
                else if (strncmp(type, "c", 1) == 0) {
                    char value = *(char*)((uintptr_t)safe + offset);
                    str = [NSString stringWithFormat:@"%s = %d", name, value];
                }
                else if (strncmp(type, "q", 1) == 0) {
                    long long value = *(long long*)((uintptr_t)safe + offset);
                    str = [NSString stringWithFormat:@"%s = %lld", name, value];
                }
                else if (strncmp(type, "Q", 1) == 0) {
                    unsigned long long value = *(unsigned long long*)((uintptr_t)safe + offset);
                    str = [NSString stringWithFormat:@"%s = %lld", name, value];
                }
                else if (strncmp(type, "@", 1) == 0) {
                    id value = object_getIvar(safe, ivar);
                    str = [NSString stringWithFormat:@"%s = %@", name, value];
                }
                
                
                if ( str ) {
                    [debugLines addObject:str];
                }
                else {
                    NSLog(@"WARNWARN Unknown iVar Type: %s", type);
                }
            }
            free(ivars);
       }
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
