//
//  FileManager.h
//  MacBox
//
//  Created by Strongbox on 15/06/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FileManager : NSObject

+ (instancetype)sharedInstance;

@property (readonly, nullable) NSURL* sharedAppGroupDirectory;

@property (readonly, nullable) NSString* userHomePath;
@property (readonly, nullable) NSURL* iCloudRootURL;
@property (readonly, nullable) NSURL* iCloudDriveRootURL;

@property (readonly) NSString* tmpEncryptedAttachmentPath;
@property (readonly) NSString* tmpAttachmentPreviewPath;
@property (readonly) NSURL* syncManagerLocalWorkingCachesDirectory;
@property (readonly) NSURL* syncManagerMergeWorkingDirectory;

- (void)deleteAllTmpAttachmentPreviewFiles;
- (void)deleteAllTmpWorkingFiles;

@property (readonly, nullable) NSURL* backupFilesDirectory;

- (void)createIfNecessary:(NSURL*)url;

@end

NS_ASSUME_NONNULL_END
