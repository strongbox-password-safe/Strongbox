//
//  SafeStorageProvider.h
//  StrongBox
//
//  Created by Mark on 19/11/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "core-model/SafeDatabase.h"
#import "SafeMetaData.h"

@protocol SafeStorageProvider <NSObject>

-(StorageProvider) getStorageId;
-(BOOL) isCloudBased;

- (void)create:(NSString*)desiredFilename data:(NSData*)data parentReference:(NSString*)parentReference viewController:(UIViewController*)viewController completionHandler:(void (^)(NSString *fileName, NSString *fileIdentifier, NSError *error))completion;
- (void)read:(SafeMetaData*)safeMetaData viewController:(UIViewController*)viewController completionHandler:(void (^)(NSData* data, NSError* error))completion;
- (void)update:(SafeMetaData*)safeMetaData data:(NSData*)data viewController:(UIViewController*)viewController completionHandler:(void (^)(NSError *error))completion;
- (void)delete:(SafeMetaData*)safeMetaData completionHandler:(void (^)(NSError *error))completion;

@end
