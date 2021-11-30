//
//  BackupsManager.h
//  Strongbox-iOS
//
//  Created by Mark on 26/09/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BackupItem.h"

#if TARGET_OS_IPHONE
//    #import <UIKit/UIKit.h>
    #import "SafeMetaData.h"
//    typedef UIViewController* VIEW_CONTROLLER_PTR;
//    typedef UIImage* IMAGE_TYPE_PTR;
    typedef SafeMetaData* METADATA_PTR;
#else

    #import "DatabaseMetadata.h"


    typedef DatabaseMetadata* METADATA_PTR;
#endif

NS_ASSUME_NONNULL_BEGIN


@interface BackupsManager : NSObject

+ (instancetype)sharedInstance;

- (BOOL)writeBackup:(NSURL*)snapshot metadata:(METADATA_PTR)metadata;
- (void)deleteBackup:(BackupItem*)item;
- (void)deleteAllBackups:(METADATA_PTR)metadata;

- (NSArray<BackupItem*>*)getAvailableBackups:(METADATA_PTR _Nullable)metadata all:(BOOL)all;

@end

NS_ASSUME_NONNULL_END
