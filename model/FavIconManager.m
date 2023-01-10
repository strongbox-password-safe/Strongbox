//
//  FavIconManager.m
//  Strongbox
//
//  Created by Mark on 23/11/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "FavIconManager.h"
#import "Node.h"
#import "NSString+Extensions.h"

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

@implementation FavIconManager

+ (instancetype)sharedInstance {
    static FavIconManager *sharedInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sharedInstance = [[FavIconManager alloc] init];
    });
    return sharedInstance;
}

- (void)getFavIconsForUrls:(NSArray<NSURL*>*)urls
                     queue:(NSOperationQueue*)queue
                   options:(FavIconDownloadOptions*)options
              withProgress:(void (^)(NSURL *url, NSArray<IMAGE_TYPE_PTR>* images))withProgress {
    for (NSURL* url in urls) {
        [queue addOperationWithBlock:^{
            
            dispatch_semaphore_t sema = dispatch_semaphore_create(0);

            NSLog(@"Downloading FavIcon for... %@", url);

            [self downloadAll:url
                      options:options
                   completion:^(NSArray<IMAGE_TYPE_PTR>* _Nullable images) {
                dispatch_semaphore_signal(sema);
                    withProgress(url, images);
            }];
            
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        }];
    }
}

- (void)downloadPreferred:(NSURL *)url
                  options:(FavIconDownloadOptions*)options
               completion:(void (^)(IMAGE_TYPE_PTR _Nullable))completion {
    url = [self cleanupUrl:url trimToDomainOnly:options.domainOnly];

    @try {
        NSError* error;
#ifndef NO_FAVICON_LIBRARY
        [FavIcon downloadAll:url
                     favIcon:options.checkCommonFavIconFiles
                    scanHtml:options.scanHtml
                  duckDuckGo:options.duckDuckGo
                      google:options.google
        allowInvalidSSLCerts:options.ignoreInvalidSSLCerts
                       error:&error
                  completion:^(NSArray<IMAGE_TYPE_PTR> * _Nullable images) {
            IMAGE_TYPE_PTR best = [self selectBest:images];
            completion(best);
        }];
#else
        NSLog(@"WARNWARN: attempt to use FavIcon library when compiled out.");
        completion(nil);
#endif
        
        if (error) {
            NSLog(@"Error: [%@]", error);
            completion(nil);
        }
    } @catch (NSException *exception) {
        NSLog(@"Exception in downloadAll: [%@]", exception);
        completion(nil);
    } @finally { }
}

- (void)downloadAll:(NSURL *)url
            options:(FavIconDownloadOptions*)options
         completion:(void (^)(NSArray<IMAGE_TYPE_PTR>* _Nullable))completion {
    url = [self cleanupUrl:url trimToDomainOnly:options.domainOnly];

    @try {
        NSError* error;
    
#ifndef NO_FAVICON_LIBRARY
        [FavIcon downloadAll:url
                     favIcon:options.checkCommonFavIconFiles
                    scanHtml:options.scanHtml
                  duckDuckGo:options.duckDuckGo
                      google:options.google
        allowInvalidSSLCerts:options.ignoreInvalidSSLCerts
                       error:&error
                  completion:^(NSArray<IMAGE_TYPE_PTR>* _Nullable images) {
           completion(images);
        }];
#else
        NSLog(@"WARNWARN: attempt to use FavIcon library when compiled out.");
        completion(@[]);
#endif
        
        if (error) {
            NSLog(@"Error: [%@]", error);
            completion(@[]);
        }
    } @catch (NSException *exception) {
        NSLog(@"Exception in downloadAll: [%@]", exception);
        completion(@[]);
    } @finally {    }
}

- (IMAGE_TYPE_PTR)selectBest:(NSArray<IMAGE_TYPE_PTR>*)images {
    NSArray<IMAGE_TYPE_PTR>* sorted = [images sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        IMAGE_TYPE_PTR imageA = (IMAGE_TYPE_PTR)obj1;
        IMAGE_TYPE_PTR imageB = (IMAGE_TYPE_PTR)obj2;
        


        
        
        if(imageA.size.width == 0) {

            return NSOrderedAscending;
        }
        if(imageB.size.width == 0) {

            return NSOrderedDescending;
        }
        
        
        
        if(imageA.size.width != imageA.size.height) {

            return NSOrderedDescending;
        }
        else if(imageB.size.width != imageB.size.height) {

            return NSOrderedAscending;
        }
        
        static const int kIdealFavIconDimension = 192;
        
        int distanceA = imageA.size.width - kIdealFavIconDimension;
        int distanceB = imageB.size.width - kIdealFavIconDimension;



        if(abs(distanceA) == abs(distanceB)) {
            return distanceA > 0 ? NSOrderedAscending : NSOrderedDescending;
        }
        else {
            return (abs(distanceA)) > (abs(distanceB)) ? NSOrderedDescending : NSOrderedAscending;
        }
        
        return NSOrderedSame;
    }];
    



    
    return sorted.firstObject;
}

- (NSURL*)cleanupUrl:(NSURL*)url trimToDomainOnly:(BOOL)trimToDomainOnly {
    

    if ( url && url.scheme.length == 0 ) {
        NSString* foo = [@"https:
        url = foo.urlExtendedParse;

    }
    
    if(url && trimToDomainOnly) {
        NSURLComponents* components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    
        if(components) {
            components.path = nil; 
            components.query = nil; 
            components.user = nil; 
            components.password = nil; 
            components.fragment = nil; 
                        
            if(components.URL.absoluteString.length && ![components.URL.absoluteString isEqualToString:url.absoluteString]) {

            }
            url = components.URL.absoluteString.length ? components.URL : url;
        }
    }
    
    return url;
}

@end
