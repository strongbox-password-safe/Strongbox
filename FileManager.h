//
//  FileManager.h
//  Strongbox
//
//  Created by Mark on 17/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "StorageBrowserItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface FileManager : NSObject

+ (instancetype)sharedInstance;

@property (readonly, nonnull) NSURL* documentsDirectory;
@property (readonly, nullable) NSURL* sharedAppGroupDirectory;
@property (readonly, nullable) NSURL* keyFilesDirectory;
@property (readonly, nullable) NSURL* backupFilesDirectory;
@property (readonly, nullable) NSURL* preferencesDirectory;
@property (readonly, nonnull) NSString* tmpEncryptedAttachmentPath;
@property (readonly, nullable) NSURL* crashFile;
@property (readonly, nullable) NSURL* archivedCrashFile;
@property (readonly, nullable) NSURL* appSupportDirectory;
@property (readonly, nullable) NSURL* syncManagerLocalWorkingCachesDirectory;
@property (readonly, nullable) NSURL* sharedLocalDeviceDatabasesDirectory;

@property (readonly, nullable) NSString* tmpAttachmentPreviewPath;

- (void)createIfNecessary:(NSURL*)url;

- (void)setDirectoryInclusionFromBackup:(BOOL)localDocuments importedKeyFiles:(BOOL)importedKeyFiles;

- (void)deleteAllLocalAndAppGroupFiles;
- (void)deleteAllInboxItems;
- (void)deleteAllTmpAttachmentPreviewFiles;

@end

NS_ASSUME_NONNULL_END
