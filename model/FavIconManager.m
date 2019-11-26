//
//  FavIconManager.m
//  Strongbox
//
//  Created by Mark on 23/11/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "FavIconManager.h"
#import "Node.h"

@import FavIcon;

const int kMaxRecommendedCustomIconDimension = 256; // Future: Setting?

@implementation FavIconManager

+ (instancetype)sharedInstance {
    static FavIconManager *sharedInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sharedInstance = [[FavIconManager alloc] init];
    });
    return sharedInstance;
}

#if TARGET_OS_IPHONE

- (void)getFavIconsForUrls:(NSArray<NSURL*>*)urls
                     queue:(NSOperationQueue*)queue
              withProgress:(void (^)(NSURL *url, UIImage* image))withProgress {
    for (NSURL* url in urls) {
        [queue addOperationWithBlock:^{
            // This is a little hacky but better than re-architecting the Library to be fully async, cancellable etc
            dispatch_semaphore_t sema = dispatch_semaphore_create(0);

            NSLog(@"Downloading FavIcon for... %@", url);

            [self downloadPreferred:url
                         completion:^(UIImage * _Nullable image) {
                dispatch_semaphore_signal(sema);

                if(image && image.size.width > 0 && image.size.height > 0) {
                    withProgress(url, image);
                }
                else {
                    withProgress(url, nil);
                }
            }];
            
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        }];
    }
}

- (void)downloadPreferred:(NSURL *)url
               completion:(void (^)(UIImage * _Nullable))completion {
    [self downloadPreferred:url
                      width:kMaxRecommendedCustomIconDimension
                     height:kMaxRecommendedCustomIconDimension
                 completion:completion];
}

- (void)downloadPreferred:(NSURL *)url
                    width:(NSUInteger)width
                   height:(NSUInteger)height
               completion:(void (^)(UIImage * _Nullable))completion {
    [FavIcon downloadPreferred:url
                         width:kMaxRecommendedCustomIconDimension
                        height:kMaxRecommendedCustomIconDimension
                    completion:^(UIImage * _Nullable image) {
        completion(image);
    }];
}
     
#endif

@end
