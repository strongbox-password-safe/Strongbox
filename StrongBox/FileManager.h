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
@property (readonly, nonnull) NSURL* offlineCacheDirectory;
@property (readonly, nonnull) NSURL* autoFillCacheDirectory;
@property (readonly, nullable) NSURL* sharedAppGroupDirectory;
@property (readonly, nullable) NSURL* keyFilesDirectory;
@property (readonly, nullable) NSURL* backupFilesDirectory;
@property (readonly, nullable) NSURL* preferencesDirectory;
@property (readonly, nonnull) NSString* tmpEncryptedAttachmentPath;
@property (readonly, nullable) NSURL* crashFile;
@property (readonly, nullable) NSURL* archivedCrashFile;
@property (readonly, nullable) NSURL* appSupportDirectory;

- (void)createIfNecessary:(NSURL*)url;

- (void)excludeDirectoriesFromBackup;
- (void)deleteAllLocalAndAppGroupFiles;
- (void)deleteAllInboxItems;
- (void)deleteAllTmpFiles;

@end

NS_ASSUME_NONNULL_END
