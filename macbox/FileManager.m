//
//  FileManager.m
//  MacBox
//
//  Created by Strongbox on 15/06/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "FileManager.h"
#include <pwd.h>

static NSString* const kEncAttachmentDirectoryName = @"_strongbox_enc_att";
static NSString* const kDefaultAppGroupName = @"group.strongbox.mac.mcguill";
static NSString* const kiCloudIdentifier = @"group.strongbox.mac.mcguill";
static NSString* const kStrongboxICloudContainerIdentifier = @"iCloud.com.strongbox";

@implementation FileManager

+ (instancetype)sharedInstance {
    static FileManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[FileManager alloc] init];
    });
    
    return sharedInstance;
}

- (NSURL *)iCloudRootURL {
    NSURL* url = [NSFileManager.defaultManager URLForUbiquityContainerIdentifier:kStrongboxICloudContainerIdentifier];
    
    if ( url ) {
        url = [url URLByAppendingPathComponent:@"Documents"];
    }
    

    
    return url;
}

- (NSURL *)iCloudDriveRootURL {
    NSURL* url = [NSFileManager.defaultManager URLForUbiquityContainerIdentifier:kStrongboxICloudContainerIdentifier];
    
    if ( url ) {
        url = [url URLByDeletingLastPathComponent];
    }
    


    return url;

}

- (NSString*)userHomePath {
    const char *rawHome = getpwuid(getuid())->pw_dir;
    return rawHome ? [NSString stringWithCString:rawHome encoding:NSUTF8StringEncoding] : nil;
}

- (NSString *)tmpEncryptedAttachmentPath {
    NSArray<NSURL*>* appSupportDirs = [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
    
    NSURL* appSupportUrl = appSupportDirs.firstObject;
    NSString* path = appSupportUrl ? appSupportUrl.path : NSTemporaryDirectory();
    
    NSString *ret =  [path stringByAppendingPathComponent:kEncAttachmentDirectoryName];
    NSError* error;
    
    if (![[NSFileManager defaultManager] createDirectoryAtPath:ret withIntermediateDirectories:YES attributes:nil error:&error]) {
        NSLog(@"Error Creating Directory: %@ => [%@]", ret, error.localizedDescription);
    }

    return ret;
}

- (NSString*)tmpAttachmentPreviewPath {
    NSString* ret = [NSTemporaryDirectory() stringByAppendingPathComponent:@"att_pr"];

    NSError* error;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:ret withIntermediateDirectories:YES attributes:nil error:&error]) {
        NSLog(@"Error Creating Directory: %@ => [%@]", ret, error.localizedDescription);
    }


    
    return ret;
}

- (void)createIfNecessary:(NSURL*)url {
    NSError* error;
    if (![[NSFileManager defaultManager] createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:&error]) {
        NSLog(@"Error Creating Directory: %@ => [%@]", url, error.localizedDescription);
    }
}

- (NSURL *)sharedAppGroupDirectory {
    NSURL* url = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:kDefaultAppGroupName];
    if(!url) {
        NSLog(@"Could not get container URL for App Group: [%@]", kDefaultAppGroupName);
        return nil;
    }
    
    [self createIfNecessary:url];
    
    return url;
}

- (NSURL *)syncManagerLocalWorkingCachesDirectory {
    NSURL* url = FileManager.sharedInstance.sharedAppGroupDirectory;
    NSURL* ret = [url URLByAppendingPathComponent:@"sync-manager/local"];
    
    [self createIfNecessary:ret];
    
    return ret;
}

- (void)deleteAllTmpAttachmentPreviewFiles {
    NSString* tmpPath = [self tmpAttachmentPreviewPath];
    
    NSArray* tmpDirectoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tmpPath error:NULL];
    
    for (NSString *file in tmpDirectoryContents) {
        NSString* path = [NSString pathWithComponents:@[tmpPath, file]];
        [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
    }
}

- (NSURL *)syncManagerMergeWorkingDirectory {
    NSURL* url = FileManager.sharedInstance.sharedAppGroupDirectory;
    NSURL* ret = [url URLByAppendingPathComponent:@"sync-manager/merge-working"];
    
    [self createIfNecessary:ret];
    
    return ret;
}

@end
