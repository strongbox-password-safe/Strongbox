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

extern const int kMaxRecommendedCustomIconDimension;

NS_ASSUME_NONNULL_BEGIN

@interface FavIconManager : NSObject

+ (instancetype)sharedInstance;

#if TARGET_OS_IPHONE

- (void)getFavIconsForUrls:(NSArray<NSURL*>*)urls
                     queue:(NSOperationQueue*)queue
              withProgress:(void (^)(NSURL *url, UIImage* _Nullable image))withProgress;
                    
- (void)downloadPreferred:(NSURL*)url
               completion:(void (^)(UIImage * _Nullable image))completion;

- (void)downloadPreferred:(NSURL*)url
                    width:(NSUInteger)width
                   height:(NSUInteger)height
               completion:(void (^)(UIImage * _Nullable image))completion;

#endif

@end

NS_ASSUME_NONNULL_END
