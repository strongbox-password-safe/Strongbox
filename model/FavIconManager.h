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
#else
#import <Cocoa/Cocoa.h>
#endif

#import "FavIconDownloadOptions.h"

//extern const int kMaxRecommendedCustomIconDimension;

NS_ASSUME_NONNULL_BEGIN

@interface FavIconManager : NSObject

+ (instancetype)sharedInstance;

#if TARGET_OS_IPHONE

- (void)getFavIconsForUrls:(NSArray<NSURL*>*)urls
                     queue:(NSOperationQueue*)queue
                   options:(FavIconDownloadOptions*)options
              withProgress:(void (^)(NSURL *url, NSArray<UIImage*>* images))withProgress;

- (void)downloadPreferred:(NSURL*)url
                  options:(FavIconDownloadOptions*)options
               completion:(void (^)(UIImage * _Nullable image))completion;

- (UIImage*)selectBest:(NSArray<UIImage*>*)images;

#endif

@end

NS_ASSUME_NONNULL_END
