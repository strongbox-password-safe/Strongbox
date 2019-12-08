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

static const int kIdealFavIconDimension = 48;

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
                   options:(FavIconDownloadOptions*)options
              withProgress:(void (^)(NSURL *url, NSArray<UIImage*>* images))withProgress {
    for (NSURL* url in urls) {
        [queue addOperationWithBlock:^{
            // This is a little hacky but better than re-architecting the Library to be fully async, cancellable etc
            dispatch_semaphore_t sema = dispatch_semaphore_create(0);

            NSLog(@"Downloading FavIcon for... %@", url);

            [self downloadAll:url
                      options:options
                   completion:^(NSArray<UIImage*>* _Nullable images) {
                dispatch_semaphore_signal(sema);
                    withProgress(url, images);
            }];
            
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        }];
    }
}

- (void)downloadPreferred:(NSURL *)url
                  options:(FavIconDownloadOptions*)options
               completion:(void (^)(UIImage * _Nullable))completion {
    url = [self cleanupUrl:url trimToDomainOnly:options.domainOnly];
    
    [FavIcon downloadAll:url
                 favIcon:options.checkCommonFavIconFiles
                scanHtml:options.scanHtml
              duckDuckGo:options.duckDuckGo
                  google:options.google
    allowInvalidSSLCerts:options.ignoreInvalidSSLCerts
              completion:^(NSArray<UIImage *>* _Nullable images) {
        UIImage* best = [self selectBest:images];
        completion(best);
    }];
}

- (void)downloadAll:(NSURL *)url
            options:(FavIconDownloadOptions*)options
         completion:(void (^)(NSArray<UIImage*>* _Nullable))completion {
    url = [self cleanupUrl:url trimToDomainOnly:options.domainOnly];
    
    [FavIcon downloadAll:url
                 favIcon:options.checkCommonFavIconFiles
                scanHtml:options.scanHtml
              duckDuckGo:options.duckDuckGo
                  google:options.google
    allowInvalidSSLCerts:options.ignoreInvalidSSLCerts
              completion:^(NSArray<UIImage *>* _Nullable images) {
        completion(images);
    }];
}

- (UIImage*)selectBest:(NSArray<UIImage*>*)images {
    NSArray<UIImage*>* sorted = [images sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        UIImage *imageA = (UIImage*)obj1;
        UIImage *imageB = (UIImage*)obj2;
        
//        NSLog(@"Comparing A and B: (%dx%d) : (%dx%d)", (int)imageA.size.width, (int)imageA.size.height, (int)imageB.size.width, (int)imageB.size.height);

        // Filter out ones that don't have dimensions
        
        if(imageA.size.width == 0) {
//            NSLog(@"Result: No Dimensions - NSOrderedAscending");
            return NSOrderedAscending;
        }
        if(imageB.size.width == 0) {
//            NSLog(@"Result: No Dimensions - NSOrderedDescending");
            return NSOrderedDescending;
        }
        
        // Filter for square dimensions
        
        if(imageA.size.width != imageA.size.height) {
//            NSLog(@"Result: Not Square - NSOrderedAscending");
            return NSOrderedDescending;
        }
        else if(imageB.size.width != imageB.size.height) {
//            NSLog(@"Result: Not Square - NSOrderedDescending");
            return NSOrderedAscending;
        }
        
        int distanceA = imageA.size.width - kIdealFavIconDimension;
        int distanceB = imageB.size.width - kIdealFavIconDimension;

//        NSLog(@"Distance from ideal - (%d) : (%d)", distanceA, distanceB);

        if(abs(distanceA) == abs(distanceB)) {
            return distanceA > 0 ? NSOrderedAscending : NSOrderedDescending;
        }
        else {
            return (abs(distanceA)) > (abs(distanceB)) ? NSOrderedDescending : NSOrderedAscending;
        }
        
        return NSOrderedSame;
    }];
    
//    for (UIImage* item in sorted) {
//        NSLog(@"%dx%d", (int)item.size.width, (int)item.size.height);
//    }
    
    return sorted.firstObject;
}

- (NSURL*)cleanupUrl:(NSURL*)url trimToDomainOnly:(BOOL)trimToDomainOnly {
    // No scheme? use default https

    if(url.scheme.length == 0) {
        NSString* foo = [@"https://" stringByAppendingString:url.absoluteString];
        url = [NSURL URLWithString:foo];
//        NSLog(@"Cleaned Up URL: [%@]", url);
    }
    
    if(trimToDomainOnly) {
        NSURLComponents* components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    
        if(components) {
            components.path = nil; //@"";
            components.query = nil; //@"";
            components.user = nil; //@"";
            components.password = nil; //@"";
            components.fragment = nil; //@"";
                        
            if(components.URL.absoluteString.length && ![components.URL.absoluteString isEqualToString:url.absoluteString]) {
//                NSLog(@"Cleaned Up URL: [%@]", components.URL);
            }
            url = components.URL.absoluteString.length ? components.URL : url;
        }
    }
    
    return url;
}

#endif

@end
