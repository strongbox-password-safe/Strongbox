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

- (void)excludeDirectoriesFromBackup;
- (void)deleteAllLocalAndAppGroupFiles;
- (void)deleteAllInboxItems;

@end

NS_ASSUME_NONNULL_END
