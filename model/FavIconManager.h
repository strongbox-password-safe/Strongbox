//
//  FavIconManager.h
//  Strongbox
//
//  Created by Mark on 23/11/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
    #import <UIKit/UIKit.h>
    typedef UIImage* IMAGE_TYPE_PTR;
#else
    #import <Cocoa/Cocoa.h>
    typedef NSImage* IMAGE_TYPE_PTR;
#endif

#import "FavIconDownloadOptions.h"

//extern const int kMaxRecommendedCustomIconDimension;

NS_ASSUME_NONNULL_BEGIN

@interface FavIconManager : NSObject

+ (instancetype)sharedInstance;

//#if TARGET_OS_IPHONE

- (void)getFavIconsForUrls:(NSArray<NSURL*>*)urls
                     queue:(NSOperationQueue*)queue
                   options:(FavIconDownloadOptions*)options
              withProgress:(void (^)(NSURL *url, NSArray<IMAGE_TYPE_PTR>* images))withProgress;

- (void)downloadPreferred:(NSURL*)url
                  options:(FavIconDownloadOptions*)options
               completion:(void (^)(IMAGE_TYPE_PTR _Nullable image))completion;

- (IMAGE_TYPE_PTR)selectBest:(NSArray<IMAGE_TYPE_PTR>*)images;

//#else //if TARGET_OS_OSX

//- (void)getFavIconsForUrls:(NSArray<NSURL*>*)urls
//                     queue:(NSOperationQueue*)queue
//                   options:(FavIconDownloadOptions*)options
//              withProgress:(void (^)(NSURL *url, NSArray<IMAGE_TYPE_PTR*>* images))withProgress;

//- (void)downloadPreferred:(NSURL*)url
//                  options:(FavIconDownloadOptions*)options
//               completion:(void (^)(NSImage * _Nullable image))completion;

//- (NSImage*)selectBest:(NSArray<NSImage*>*)images;

//#endif

@end

NS_ASSUME_NONNULL_END
