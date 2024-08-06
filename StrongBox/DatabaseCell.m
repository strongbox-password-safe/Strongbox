//
//  DatabaseCell.m
//  Strongbox
//
//  Created by Mark on 30/07/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "DatabaseCell.h"
#import "DatabasePreferences.h"
#import "DatabaseCellSubtitleField.h"
#import "AppPreferences.h"
#import "SafeStorageProviderFactory.h"
#import "Utils.h"
#import "NSDate+Extensions.h"
#import "SyncManager.h"
#import "WorkingCopyManager.h"
#import "LocalDeviceStorageProvider.h"

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

NSString* const kDatabaseCell = @"DatabaseCell";

@interface DatabaseCell ()

@property (weak, nonatomic) IBOutlet UIImageView *providerIcon;
@property (weak, nonatomic) IBOutlet UILabel *name;
@property (weak, nonatomic) IBOutlet UILabel *subtitle1;
@property (weak, nonatomic) IBOutlet UILabel *subtitle2;
@property (weak, nonatomic) IBOutlet UILabel *topSubtitle;
@property (weak, nonatomic) IBOutlet UIView *bottomRow;

@property (weak, nonatomic) IBOutlet UIImageView *status1;
@property (weak, nonatomic) IBOutlet UIImageView *status2;
@property (weak, nonatomic) IBOutlet UIImageView *status3;
@property (weak, nonatomic) IBOutlet UIImageView *status4;
@property (weak, nonatomic) IBOutlet UIImageView *status5;
@property (weak, nonatomic) IBOutlet UIImageView *status6;

@end

@implementation DatabaseCell

- (void)prepareForReuse {
    [super prepareForReuse];
    


    self.bottomRow.hidden = NO;
    self.subtitle1.hidden = NO;
    self.subtitle2.hidden = NO;
    self.topSubtitle.hidden = NO;
    
    self.status1.image = nil;
    self.status1.hidden = YES;
    self.status2.image = nil;
    self.status2.hidden = YES;
    self.status3.image = nil;
    self.status3.hidden = YES;
    self.status4.image = nil;
    self.status4.hidden = YES;
    self.status5.image = nil;
    self.status5.hidden = YES;
    self.status6.image = nil;
    self.status6.hidden = YES;
}

- (void)setEnabled:(BOOL)enabled {
    self.imageView.userInteractionEnabled = enabled;
    self.userInteractionEnabled = enabled;
    self.textLabel.enabled = enabled;
    self.detailTextLabel.enabled = enabled;
    self.name.enabled = enabled;
    self.subtitle1.enabled = enabled;
    self.subtitle2.enabled = enabled;
    self.providerIcon.userInteractionEnabled = enabled;
    self.topSubtitle.enabled = enabled;
    
    self.status1.userInteractionEnabled = enabled;
    self.status2.userInteractionEnabled = enabled;
    self.status3.userInteractionEnabled = enabled;
    self.status4.userInteractionEnabled = enabled;
    self.status5.userInteractionEnabled = enabled;
    self.status6.userInteractionEnabled = enabled;
}

- (void)setContent:(NSString*)name
       topSubtitle:(NSString*)topSubtitle
         subtitle1:(NSString*)subtitle1
         subtitle2:(NSString*)subtitle2
      providerIcon:(UIImage*)providerIcon {
    [self set:name topSubtitle:topSubtitle subtitle1:subtitle1 subtitle2:subtitle2 providerIcon:providerIcon statusImages:@[] rotateLastImage:NO tints:@[] disabled:NO];
}

- (void)set:(NSString*)name
topSubtitle:(NSString*)topSubtitle
  subtitle1:(NSString*)subtitle1
  subtitle2:(NSString*)subtitle2
providerIcon:(UIImage*)providerIcon
statusImages:(NSArray<UIImage*>*)statusImages
rotateLastImage:(BOOL)rotateLastImage
      tints:(nonnull NSArray *)tints
   disabled:(BOOL)disabled {

    
    self.name.text = name;

    self.providerIcon.image = providerIcon;
    self.providerIcon.hidden = providerIcon == nil;

    self.topSubtitle.text = topSubtitle ? topSubtitle : @"";
    self.subtitle1.text = subtitle1 ? subtitle1 : @"";
    self.subtitle2.text = subtitle2 ? subtitle2 : @"";
    
    self.subtitle1.hidden = subtitle1 == nil;
    self.subtitle2.hidden = subtitle2 == nil;
    self.topSubtitle.hidden = topSubtitle == nil;
    
    self.bottomRow.hidden = subtitle1 == nil && subtitle2 == nil;

    NSArray<UIImageView*>* statusImageControls = @[self.status1, self.status2, self.status3, self.status4, self.status5, self.status6];
    
    for (int i = 0; i < statusImageControls.count; i++) {
        UIImage* image = i < statusImages.count ? statusImages[i] : nil;
        
        statusImageControls[i].image = image;
        statusImageControls[i].hidden = image == nil;
        statusImageControls[i].tintColor = (image != nil && tints && (tints[i] != NSNull.null)) ? tints[i] : nil;
        
        [self runSpinAnimationOnView:statusImageControls[i] doIt:(i == statusImages.count - 1 && rotateLastImage) duration:1.0 rotations:1.0 repeat:1024 * 1024];
    }
    
    [self setEnabled:!disabled];
}

- (void)runSpinAnimationOnView:(UIView*)view doIt:(BOOL)doIt duration:(CGFloat)duration rotations:(CGFloat)rotations repeat:(float)repeat {


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



- (void)populateCell:(DatabasePreferences*)database {
    [self populateCell:database disabled:NO];
}

- (void)populateCell:(DatabasePreferences *)database disabled:(BOOL)disabled {
    [self populateCell:database disabled:disabled autoFill:NO];
}

- (void)populateCell:(DatabasePreferences *)database disabled:(BOOL)disabled autoFill:(BOOL)autoFill {
    SyncOperationState syncState = autoFill ? kSyncOperationStateInitial : [SyncManager.sharedInstance getSyncStatus:database].state;
    
    if ( AppPreferences.sharedInstance.disableNetworkBasedFeatures ) {
        if ( database.storageProvider != kLocalDevice && database.storageProvider != kFilesAppUrlBookmark ) {
            disabled = YES;
        }
    }
    
    NSArray* tints;
    NSArray<UIImage*>* statusImages =  [self getStatusImages:database syncState:syncState tints:&tints];
        
    NSString* topSubtitle = [self getDatabaseCellSubtitleField:database field:AppPreferences.sharedInstance.databaseCellTopSubtitle];
    NSString* subtitle1 = [self getDatabaseCellSubtitleField:database field:AppPreferences.sharedInstance.databaseCellSubtitle1];
    NSString* subtitle2 = [self getDatabaseCellSubtitleField:database field:AppPreferences.sharedInstance.databaseCellSubtitle2];
    
    UIImage* databaseIcon = AppPreferences.sharedInstance.showDatabaseIcon ? [SafeStorageProviderFactory getImageForProvider:database.storageProvider database:database] : nil;

    if ( disabled ) {
        databaseIcon = AppPreferences.sharedInstance.showDatabaseIcon ? [UIImage imageNamed:@"cancel"] : nil;
        
        if (autoFill) {
            subtitle2 = database.autoFillEnabled ?
                NSLocalizedString(@"autofill_vc_item_subtitle_local_copy_unavailable", @"Local Copy Unavailable") :
                NSLocalizedString(@"autofill_vc_item_subtitle_disabled", @"AutoFill Disabled");
        }
    }
    
    [self set:database.nickName
  topSubtitle:topSubtitle
    subtitle1:subtitle1
    subtitle2:subtitle2
 providerIcon:databaseIcon
 statusImages:statusImages
     rotateLastImage:syncState == kSyncOperationStateInProgress
        tints:tints
     disabled:disabled];
}



- (NSArray<UIImage*>*)getStatusImages:(DatabasePreferences*)database syncState:(SyncOperationState)syncState tints:(NSArray**)tints {
    NSMutableArray<UIImage*> *ret = NSMutableArray.array;
    NSMutableArray *tnts = NSMutableArray.array;

    
    
    if(database.hasUnresolvedConflicts) {
        [ret addObject:[UIImage imageNamed:@"error"]];
        [tnts addObject:NSNull.null];
    }
    
    
    
    if ( database.storageProvider == kCloudKit ) {
        BOOL shared = database.isSharedInCloudKit;

        if ( shared ) {
            UIImage* cloudkitSharedIndicator = [UIImage systemImageNamed:@"person.2.fill"];
            
            BOOL iOwn = database.isOwnedByMeCloudKit;
            
            NSArray<UIColor*>* colors = iOwn ?  @[UIColor.systemGreenColor, UIColor.systemBlueColor] : @[UIColor.systemBlueColor, UIColor.systemGreenColor];
            
            UIImageSymbolConfiguration* config = [UIImageSymbolConfiguration configurationWithPaletteColors:colors];
            UIImage* coloured = [cloudkitSharedIndicator imageByApplyingSymbolConfiguration:config];
            
            [ret addObject:coloured];
            [tnts addObject:NSNull.null];
        }
    }
    
    if (AppPreferences.sharedInstance.showDatabaseStatusIcon) {
        NSString* quickLaunchUuid = AppPreferences.sharedInstance.quickLaunchUuid;
        NSString* afQuickLaunchUuid = AppPreferences.sharedInstance.autoFillQuickLaunchUuid;

        BOOL isQuickLaunch = [quickLaunchUuid isEqualToString:database.uuid];
        BOOL isAFQuickLaunch = [afQuickLaunchUuid isEqualToString:database.uuid];
    
        
        
        if ( isQuickLaunch ) {
            [ret addObject:[UIImage imageNamed:@"rocket"]];
            [tnts addObject:NSNull.null];
        }
        
        
        
        if ( isAFQuickLaunch && !isQuickLaunch ) {
            if ( database.autoFillEnabled ) {
                [ret addObject:[UIImage imageNamed:@"globe"]];
                [tnts addObject:UIColor.systemGreenColor];
            }
        }
        
        
        
        if(database.readOnly) {
            [ret addObject:[UIImage systemImageNamed:@"eyeglasses"]];
            [tnts addObject:UIColor.systemGrayColor];
        }
    }
        
    
    
    if (database.outstandingUpdateId) {
        [ret addObject:[UIImage imageNamed:@"upload"]];
        [tnts addObject:UIColor.orangeColor];
    }
    
    
    
    if (syncState == kSyncOperationStateInProgress ||
        syncState == kSyncOperationStateError ||
        syncState == kSyncOperationStateBackgroundButUserInteractionRequired ||
        syncState == kSyncOperationStateUserCancelled) {
        UIImage* syncImage = [UIImage systemImageNamed:@"arrow.triangle.2.circlepath"];
        
        [ret addObject:syncImage];
        [tnts addObject:syncState == kSyncOperationStateError ? UIColor.redColor : (syncState == kSyncOperationStateInProgress ? NSNull.null : UIColor.orangeColor)];
    }
    
    if(tints) {
        *tints = tnts;
    }
    
    return ret;
}

- (NSString*)getDatabaseCellSubtitleField:(DatabasePreferences*)database field:(DatabaseCellSubtitleField)field {
    switch (field) {
        case kDatabaseCellSubtitleFieldNone:
            return nil;
            break;
        case kDatabaseCellSubtitleFieldFileName:
            return database.fileName;
            break;
        case kDatabaseCellSubtitleFieldLastModifiedDate:
            return [self getModifiedDate:database];
            break;
        case kDatabaseCellSubtitleFieldLastModifiedDatePrecise:
            return [self getModifiedDatePrecise:database];
            break;
        case kDatabaseCellSubtitleFieldFileSize:
            return [self getLocalWorkingCopyFileSize:database];
            break;
        case kDatabaseCellSubtitleFieldStorage:
            return [self getStorageString:database];
            break;
        case kDatabaseCellSubtitleFieldCreateDate:
            return [self getCreateDate:database];
            break;
        case kDatabaseCellSubtitleFieldCreateDatePrecise:
            return [self getCreateDatePrecise:database];
            break;
        default:
            return @"<Unknown Field>";
            break;
    }
}

- (NSString*)getCreateDate:(DatabasePreferences*)safe {
    NSURL* url = [WorkingCopyManager.sharedInstance getLocalWorkingCache:safe.uuid];
    NSError* error;
    NSDictionary* attributes = [NSFileManager.defaultManager attributesOfItemAtPath:url.path error:&error];
    
    if (error) {
        slog(@"Could not get local working cache at [%@]-[%@]", url, error);
        return @"";
    }

    NSDate* created = attributes.fileCreationDate;
    return created ? created.friendlyDateStringVeryShort : @"";
}

- (NSString*)getCreateDatePrecise:(DatabasePreferences*)safe {
    NSURL* url = [WorkingCopyManager.sharedInstance getLocalWorkingCache:safe.uuid];
    NSError* error;
    NSDictionary* attributes = [NSFileManager.defaultManager attributesOfItemAtPath:url.path error:&error];
    
    if (error) {
        slog(@"Could not get local working cache at [%@]-[%@]", url, error);
        return @"";
    }

    NSDate* created = attributes.fileCreationDate;
    return created ? created.friendlyDateTimeStringPrecise : @"";
}

- (NSString*)getModifiedDate:(DatabasePreferences*)safe {
    NSDate* mod;
    [WorkingCopyManager.sharedInstance isLocalWorkingCacheAvailable:safe.uuid modified:&mod];
    return mod ? mod.friendlyDateStringVeryShort : @"";
}

- (NSString*)getModifiedDatePrecise:(DatabasePreferences*)safe {
    NSDate* mod;
    [WorkingCopyManager.sharedInstance isLocalWorkingCacheAvailable:safe.uuid modified:&mod];
    return mod ? mod.friendlyDateTimeStringPrecise : @"";
}

- (NSString*)getLocalWorkingCopyFileSize:(DatabasePreferences*)safe {
    unsigned long long fileSize;
    NSURL* url = [WorkingCopyManager.sharedInstance getLocalWorkingCache:safe.uuid modified:nil fileSize:&fileSize];
    return url ? friendlyFileSizeString(fileSize) : @"";
}

- (NSString*)getStorageString:(DatabasePreferences*)database {
    return [SafeStorageProviderFactory getStorageDisplayName:database];
}

@end
