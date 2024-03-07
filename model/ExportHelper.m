//
//  ExportHelper.m
//  Strongbox
//
//  Created by Strongbox on 25/02/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

#import "ExportHelper.h"
#import "DatabasePreferences.h"
#import "AppPreferences.h"
#import "WorkingCopyManager.h"
#import "Utils.h"
#import "Strongbox-Swift.h"

@implementation ExportHelper

+ (NSURL*)getExportFile:(DatabasePreferences*)database error:(NSError**)error {
    if (!database) {
        return nil;
    }
    
    NSString* filename = AppPreferences.sharedInstance.appendDateToExportFileName ? database.exportFilename : database.fileName;
    NSString* f = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
    
    [NSFileManager.defaultManager removeItemAtPath:f error:nil];
    
    NSURL* localCopyUrl = [WorkingCopyManager.sharedInstance getLocalWorkingCache:database.uuid];
    if (!localCopyUrl) {
        if ( error ) {
            *error = [Utils createNSError:@"Could not get local copy" errorCode:-2145];
        }
        return nil;
    }
    
    NSError* err;
    NSData* data = [NSData dataWithContentsOfURL:localCopyUrl options:kNilOptions error:&err];
    if (err) {
        if ( error ) {
            *error = err;
        }
        return nil;
    }
    
    [data writeToFile:f options:kNilOptions error:&err];
    if (err) {
        if ( error ) {
            *error = err;
        }
        return nil;
    }
    
    NSURL* fileUrl = [NSURL fileURLWithPath:f];
    
    
    
    NSURL* url;
    if ( AppPreferences.sharedInstance.zipExports ) {
        NSError* zipError;
        NSURL* zippedUrl = [Zipper zipFile:fileUrl error:&zipError];
        if ( zippedUrl == nil ) {
            if ( error ) {
                *error = zipError;
            }
            return nil;
        }
        
        url = zippedUrl;
    }
    else {
        url = fileUrl;
    }
    
    return url;
}

+ (void)cleanupExportFiles:(NSURL *)url {
    if ( url ) {
        NSError* error;
        
        [[NSFileManager defaultManager] removeItemAtURL:url error:&error];
        
        NSString* ext = url.pathExtension.lowercaseString;
        
        if ( [ext isEqualToString:@"zip"]) {
            NSURL* fileUrl = url.URLByDeletingPathExtension;
            [[NSFileManager defaultManager] removeItemAtURL:fileUrl error:nil];
        }
    }
}

@end
