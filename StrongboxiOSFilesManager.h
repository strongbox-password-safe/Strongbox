//
//  FileManager.h
//  Strongbox
//
//  Created by Mark on 17/06/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "StorageBrowserItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface StrongboxFilesManager : NSObject

+ (instancetype)sharedInstance;

@property (readonly, nonnull) NSURL* documentsDirectory;
@property (readonly, nullable) NSURL* sharedAppGroupDirectory;
@property (readonly, nullable) NSURL* keyFilesDirectory;
@property (readonly, nullable) NSURL* backupFilesDirectory;
@property (readonly, nullable) NSURL* preferencesDirectory;
@property (readonly, nonnull) NSString* tmpEncryptionStreamPath;
@property (readonly, nullable) NSURL* crashFile;
@property (readonly, nullable) NSURL* archivedCrashFile;
@property (readonly, nullable) NSURL* appSupportDirectory;
@property (readonly, nullable) NSURL* syncManagerLocalWorkingCachesDirectory;
@property (readonly, nullable) NSURL* syncManagerMergeWorkingDirectory;


@property (readonly, nonnull) NSString* tmpAttachmentPreviewPath;

- (void)createIfNecessary:(NSURL*)url;

- (void)setDirectoryInclusionFromBackup:(BOOL)localDocuments importedKeyFiles:(BOOL)importedKeyFiles;

- (void)deleteAllLocalAndAppGroupFiles;
- (void)deleteAllInboxItems;
- (void)deleteAllTmpAttachmentFiles;
- (void)deleteAllTmpWorkingFiles;
- (void)deleteAllTmpDirectoryFiles;

- (void)setFileProtection:(BOOL)complete;

@property (readonly) NSArray<NSURL*>* importedKeyFiles;

@end

NS_ASSUME_NONNULL_END
