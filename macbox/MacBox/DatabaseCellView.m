//
//  DatabaseCellView.m
//  MacBox
//
//  Created by Strongbox on 18/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "DatabaseCellView.h"
#import "ClickableTextField.h"
#import "BookmarksHelper.h"
#import "Utils.h"
#import "NSDate+Extensions.h"
#import "MacUrlSchemes.h"
#import "WorkingCopyManager.h"
#import "FileManager.h"

@interface DatabaseCellView () <NSTextFieldDelegate>

@property (weak) IBOutlet ClickableTextField *textFieldName;
@property (weak) IBOutlet NSTextField *textFieldSubtitleLeft;
@property (weak) IBOutlet NSTextField *textFieldSubtitleTopRight;
@property (weak) IBOutlet NSTextField *textFieldSubtitleBottomRight;

@end

@implementation DatabaseCellView

- (void)setWithDatabase:(DatabaseMetadata*)metadata {
    [self setWithDatabase:metadata autoFill:NO];
}

- (void)setWithDatabase:(DatabaseMetadata*)metadata autoFill:(BOOL)autoFill {
    self.textFieldName.stringValue = @"";
    self.textFieldSubtitleLeft.stringValue = @"";
    self.textFieldSubtitleTopRight.stringValue = @"";
    self.textFieldSubtitleBottomRight.stringValue = @"";

    @try {
        NSString* path = @"";
        NSString* fileSize = @"";
        NSString* fileMod = @"";
        NSString* title = metadata.nickName ? metadata.nickName : @"";
        
        title = metadata.outstandingUpdateId ? [title stringByAppendingString:@" (Update Pending)"] : title; 
    
        if ( ![metadata.fileUrl.scheme isEqualToString:kStrongboxFileUrlScheme] ) {
            NSURLComponents *comp = [[NSURLComponents alloc] init];
            comp.scheme = metadata.fileUrl.scheme;
            comp.host = metadata.fileUrl.host;
            
            path = [NSString stringWithFormat:@"%@ (%@)", metadata.fileUrl.lastPathComponent, comp.URL.absoluteString];
            
            NSDate* modDate;
            unsigned long long size;
            NSURL* workingCopy = [WorkingCopyManager.sharedInstance getLocalWorkingCache:metadata modified:&modDate fileSize:&size];
            
            if ( workingCopy ) {
                fileSize = friendlyFileSizeString(size);
                fileMod = modDate.friendlyDateTimeStringPrecise;
            }
        }
        else {
            NSString* storageInfo = autoFill ? metadata.autoFillStorageInfo : metadata.storageInfo;
            
            NSURL* url = [BookmarksHelper getExpressUrlFromBookmark:storageInfo];
            url = url ? url : metadata.fileUrl; 
            
            if ( url ) {
                if ( [NSFileManager.defaultManager isUbiquitousItemAtURL:url] ) {
                    path = [self getFriendlyICloudPath:url.path];
                }
                else {
                    path = [self getPathRelativeToUserHome:url.path];
                }
                
                NSError* error;
                NSDictionary* attr = [NSFileManager.defaultManager attributesOfItemAtPath:url.path error:&error];
                if (error) {
                    NSLog(@"Error getting attributes of database file: [%@]", error);
                }
                else {
                    fileSize = friendlyFileSizeString(attr.fileSize);
                    fileMod = attr.fileModificationDate.friendlyDateTimeStringPrecise;
                }
            }
        }

        self.textFieldName.stringValue = title;
        self.textFieldSubtitleLeft.stringValue = path;
        self.textFieldSubtitleTopRight.stringValue = fileSize;
        self.textFieldSubtitleBottomRight.stringValue = fileMod;
    } @catch (NSException *exception) {
        NSLog(@"Exception getting display attributes for database: %@", exception);
    }
}

- (NSString*)getPathRelativeToUserHome:(NSString*)path {
    NSString* userHome = FileManager.sharedInstance.userHomePath;
    
    if ( userHome && path.length > userHome.length ) {
        path = [path stringByReplacingOccurrencesOfString:userHome withString:@"~" options:kNilOptions range:NSMakeRange(0, userHome.length)];
    }
    
    return path;
}

- (NSString*)getFriendlyICloudPath:(NSString*)path {
    NSURL* iCloudRoot = FileManager.sharedInstance.iCloudRootURL;
    NSURL* iCloudDriveRoot = FileManager.sharedInstance.iCloudDriveRootURL;

    
    
    if ( iCloudRoot && path.length > iCloudRoot.path.length && [[path substringToIndex:iCloudRoot.path.length] isEqualToString:iCloudRoot.path]) {
        return [NSString stringWithFormat:@"%@ (%@)", path.lastPathComponent, NSLocalizedString(@"databases_vc_database_location_suffix_database_is_in_official_icloud_strongbox_folder", @"Strongbox iCloud")];
    }
    
    
    
    if ( iCloudDriveRoot && path.length > iCloudDriveRoot.path.length && [[path substringToIndex:iCloudDriveRoot.path.length] isEqualToString:iCloudDriveRoot.path]) {
        NSArray *iCloudDriveDisplayComponents = [NSFileManager.defaultManager componentsToDisplayForPath:iCloudDriveRoot.path];
        NSArray *pathDisplayComponents = [NSFileManager.defaultManager componentsToDisplayForPath:path];

        if ( pathDisplayComponents.count > iCloudDriveDisplayComponents.count ) {
            NSArray* relative = [pathDisplayComponents subarrayWithRange:NSMakeRange(iCloudDriveDisplayComponents.count, pathDisplayComponents.count - iCloudDriveDisplayComponents.count)];
            
            if ( relative.count > 1 ) {
                NSString* niceICloudDriveName = relative.firstObject;
                NSArray* pathWithiniCloudDrive = [relative subarrayWithRange:NSMakeRange(1, relative.count-1)];
                NSString* strPathWithiniCloudDrive = [pathWithiniCloudDrive componentsJoinedByString:@"/"];
                return [NSString stringWithFormat:@"%@ (%@)", strPathWithiniCloudDrive, niceICloudDriveName];
            }
        }
    }

    return [self getPathRelativeToUserHome:path];
}

- (void)enableEditing:(BOOL)enable {
    self.textFieldName.editable = enable;
}

@end
