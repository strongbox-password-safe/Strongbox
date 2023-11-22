//
//  FavIconManager.h
//  Strongbox
//
//  Created by Mark on 23/11/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FavIconDownloadOptions.h"
#import "NodeIcon.h"

NS_ASSUME_NONNULL_BEGIN

@interface FavIconManager : NSObject

+ (instancetype)sharedInstance;

- (void)getFavIconsForUrls:(NSArray<NSURL*>*)urls
                     queue:(NSOperationQueue*)queue
                   options:(FavIconDownloadOptions*)options
                completion:(void (^ _Nullable)(NSArray<NodeIcon*>* images))completion;

- (void)downloadPreferred:(NSURL*)url
                  options:(FavIconDownloadOptions*)options
               completion:(void (^)(NodeIcon* _Nullable image))completion;

- (NodeIcon* _Nullable)getIdealImage:(NSArray<NodeIcon*>*)images
                             options:(FavIconDownloadOptions*)options;

- (NSArray<NodeIcon*>*)getSortedImages:(NSArray<NodeIcon*> *)images
                               options:(FavIconDownloadOptions *)options;

@end

NS_ASSUME_NONNULL_END
