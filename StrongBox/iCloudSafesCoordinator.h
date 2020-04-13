//
//  Hybrid.h
//  Strongbox
//
//  Created by Mark on 25/09/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeStorageProvider.h"
#import "AppleICloudOrLocalSafeFile.h"

NS_ASSUME_NONNULL_BEGIN

@interface iCloudSafesCoordinator : NSObject

+ (instancetype)sharedInstance;

- (void)initializeiCloudAccessWithCompletion:(void (^)(BOOL available)) completion;
- (void)startQuery;

@property (nonatomic, copy) void (^showMigrationUi)(BOOL show);

-(NSURL*)getFullICloudURLWithFileName:(NSString *)filename;
-(NSString*)getUniqueICloudFilename:(NSString *)prefix extension:(NSString*)extension;

- (void)migrateLocalToiCloud:(void (^)(BOOL show)) completion;
- (void)migrateiCloudToLocal:(void (^)(BOOL show)) completion;

@property (nullable, readonly) NSURL* iCloudDocumentsFolder;

@end

NS_ASSUME_NONNULL_END
