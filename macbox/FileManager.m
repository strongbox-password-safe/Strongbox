//
//  FileManager.m
//  MacBox
//
//  Created by Strongbox on 15/06/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "FileManager.h"

static NSString* const kEncAttachmentDirectoryName = @"_strongbox_enc_att";

@implementation FileManager

+ (instancetype)sharedInstance {
    static FileManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[FileManager alloc] init];
    });
    
    return sharedInstance;
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

    NSLog(@"Temp Attachment Path = [%@]", ret);
    
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

@end
