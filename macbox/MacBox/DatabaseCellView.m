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
#import "Settings.h"
#import "MacSyncManager.h"
#import <QuartzCore/QuartzCore.h>

@interface DatabaseCellView () <NSTextFieldDelegate>

@property (weak) IBOutlet ClickableTextField *textFieldName;
@property (weak) IBOutlet NSTextField *textFieldSubtitleLeft;
@property (weak) IBOutlet NSTextField *textFieldSubtitleTopRight;
@property (weak) IBOutlet NSTextField *textFieldSubtitleBottomRight;

@property (weak) IBOutlet NSImageView *imageViewQuickLaunch;
@property (weak) IBOutlet NSImageView *imageViewOutstandingUpdate;
@property (weak) IBOutlet NSImageView *imageViewReadOnly;
@property (weak) IBOutlet NSImageView *imageViewSyncing;

@end

@implementation DatabaseCellView

- (void)setWithDatabase:(DatabaseMetadata*)metadata {
    [self setWithDatabase:metadata autoFill:NO];
}

- (void)determineFields:(DatabaseMetadata*)metadata autoFill:(BOOL)autoFill {
    NSString* path = @"";
    NSString* fileSize = @"";
    NSString* fileMod = @"";
    NSString* title = metadata.nickName ? metadata.nickName : @"";
    
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
}

- (void)setWithDatabase:(DatabaseMetadata*)metadata autoFill:(BOOL)autoFill {
    self.textFieldName.stringValue = @"";
    self.textFieldSubtitleLeft.stringValue = @"";
    self.textFieldSubtitleTopRight.stringValue = @"";
    self.textFieldSubtitleBottomRight.stringValue = @"";
    
    self.imageViewQuickLaunch.hidden = YES;
    self.imageViewOutstandingUpdate.hidden = YES;
    self.imageViewReadOnly.hidden = YES;
    self.imageViewSyncing.hidden = YES;
   
    @try {
        [self determineFields:metadata autoFill:autoFill];
    
        self.imageViewQuickLaunch.hidden = !metadata.launchAtStartup;
        self.imageViewOutstandingUpdate.hidden = metadata.outstandingUpdateId == nil;
        
        SyncOperationState syncState = autoFill ? kSyncOperationStateInitial : [MacSyncManager.sharedInstance getSyncStatus:metadata].state;
        if (syncState == kSyncOperationStateInProgress ||
            syncState == kSyncOperationStateError ||
            syncState == kSyncOperationStateBackgroundButUserInteractionRequired ||
            syncState == kSyncOperationStateUserCancelled) {
            
            self.imageViewSyncing.hidden = NO;
            if (@available(macOS 10.14, *)) {
                NSColor *tint = syncState == kSyncOperationStateError ? NSColor.systemRedColor : (syncState == kSyncOperationStateInProgress ? NSColor.systemBlueColor : NSColor.systemOrangeColor);
                self.imageViewSyncing.contentTintColor = tint;
            }
            
            
            

            
        }
    } @catch (NSException *exception) {
        NSLog(@"Exception getting display attributes for database: %@", exception);
    }
}

- (void)runSpinAnimationOnView:(NSView*)view doIt:(BOOL)doIt duration:(CGFloat)duration rotations:(CGFloat)rotations repeat:(float)repeat {


    [view.layer removeAllAnimations];
    
    if (doIt) {
        CABasicAnimation* rotationAnimation;
        rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
        rotationAnimation.toValue = [NSNumber numberWithFloat: M_PI * 2.0 /* full rotation*/ * rotations * duration ];
        rotationAnimation.duration = duration;
        rotationAnimation.cumulative = YES;
        rotationAnimation.repeatCount = repeat ? HUGE_VALF : 0;
        [rotationAnimation setRemovedOnCompletion:NO]; 
        
        [view.layer addAnimation:rotationAnimation forKey:@"rotationAnimation"];
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
