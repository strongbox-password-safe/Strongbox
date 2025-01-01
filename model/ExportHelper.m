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

+ (void)getExportFile:(UIViewController *)viewController
             database:(DatabasePreferences *)database
           completion:(void (^)(NSURL * _Nullable, NSError * _Nullable))completion {
    NSString* filename = AppPreferences.sharedInstance.appendDateToExportFileName ? database.exportFilename : database.fileName;
    NSString* f = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
    
    [NSFileManager.defaultManager removeItemAtPath:f error:nil];
    
    NSURL* localCopyUrl = [WorkingCopyManager.sharedInstance getLocalWorkingCache:database.uuid];
    if (!localCopyUrl) {
        completion(nil, [Utils createNSError:@"Could not get local copy" errorCode:-2145]);
        return;
    }
    
    NSError* err;
    NSData* data = [NSData dataWithContentsOfURL:localCopyUrl options:kNilOptions error:&err];
    if (err) {
        completion(nil, err);
        return;
    }
    
    [data writeToFile:f options:kNilOptions error:&err];
    if (err) {
        completion(nil, err);
        return;
    }
    
    NSURL* fileUrl = [NSURL fileURLWithPath:f];
    
    
    
    if ( AppPreferences.sharedInstance.zipExportBehaviour == 0 ) { 
        [Alerts yesNo:viewController
                title:NSLocalizedString(@"zip_export_question", @"Zip Export?")
              message:NSLocalizedString(@"zip_export_file_prompt_message", @"Strongbox can zip this export file if you prefer.\n\nWould you like to zip the export file?")
               action:^(BOOL response) {
            if ( response ) { 
                [ExportHelper onContinueExport:fileUrl zip:YES completion:completion];
            }
            else { 
                [ExportHelper onContinueExport:fileUrl zip:NO completion:completion];
            }
        }];
    }
    else {
        BOOL zip = (AppPreferences.sharedInstance.zipExportBehaviour == 1);
        [ExportHelper onContinueExport:fileUrl zip:zip completion:completion];
    }
}

+ (void)onContinueExport:(NSURL*)fileUrl zip:(BOOL)zip completion:(void (^)(NSURL * _Nullable, NSError * _Nullable))completion {
    NSURL* url;
    if ( zip ) {
        NSError* zipError;
        NSURL* zippedUrl = [Zipper zipFile:fileUrl error:&zipError];
        if ( zippedUrl == nil ) {
            completion(nil, zipError);
            return;
        }
        
        url = zippedUrl;
    }
    else {
        url = fileUrl;
    }
    
    completion(url, nil);
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
