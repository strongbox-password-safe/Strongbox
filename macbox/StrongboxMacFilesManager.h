//
//  FileManager.h
//  MacBox
//
//  Created by Strongbox on 15/06/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface StrongboxFilesManager : NSObject

+ (instancetype)sharedInstance;

@property (readonly, nullable) NSURL* sharedAppGroupDirectory;

@property (readonly, nullable) NSString* userHomePath;
@property (readonly, nullable) NSURL* iCloudRootURL;
@property (readonly, nullable) NSURL* iCloudDriveRootURL;
@property (readonly, nullable) NSString* desktopPath;

@property (readonly, nonnull) NSString* tmpAttachmentPreviewPath;
@property (readonly) NSURL* syncManagerLocalWorkingCachesDirectory;
@property (readonly) NSURL* syncManagerMergeWorkingDirectory;

@property (readonly, nonnull) NSString* tmpEncryptionStreamPath;

- (void)deleteAllTmpAttachmentPreviewFiles;
- (void)deleteAllTmpWorkingFiles;
- (void)deleteAllNukeFromOrbit;

@property (readonly, nullable) NSURL* backupFilesDirectory;
@property (readonly, nullable) NSURL* preferencesDirectory;

- (void)createIfNecessary:(NSURL*)url;

@end

NS_ASSUME_NONNULL_END
