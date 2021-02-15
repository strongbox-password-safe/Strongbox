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

@property (readonly, nullable) NSString* userHomePath;
@property (readonly, nullable) NSURL* iCloudRootURL;
@property (readonly, nullable) NSURL* iCloudDriveRootURL;

@property (readonly) NSString* tmpEncryptedAttachmentPath;
@property (readonly) NSString* tmpAttachmentPreviewPath;
@property (readonly) NSURL* syncManagerLocalWorkingCachesDirectory;

- (void)deleteAllTmpAttachmentPreviewFiles;

@end

NS_ASSUME_NONNULL_END
