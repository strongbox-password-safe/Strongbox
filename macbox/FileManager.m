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
    NSString *ret =  [NSTemporaryDirectory() stringByAppendingPathComponent:kEncAttachmentDirectoryName];
    NSError* error;
    
    if (![[NSFileManager defaultManager] createDirectoryAtPath:ret withIntermediateDirectories:YES attributes:nil error:&error]) {
        NSLog(@"Error Creating Directory: %@ => [%@]", ret, error.localizedDescription);
    }

    return ret;
}

@end
