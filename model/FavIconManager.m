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
#import "NSArray+Extensions.h"

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

- (void)getFavIconsForUrls:(NSArray<NSURL *> *)urls
                     queue:(NSOperationQueue *)queue
                   options:(FavIconDownloadOptions *)options
                completion:(void (^)(NSArray<NodeIcon *> * _Nonnull))completion {
    [queue addOperationWithBlock:^{
        __block NSMutableArray<NodeIcon*>* allImages = NSMutableArray.array;
        
        for (NSURL* url in urls) {
            
            dispatch_semaphore_t sema = dispatch_semaphore_create(0);
            
            [self downloadAll:url
                      options:options
                   completion:^(NSArray<NodeIcon *> * _Nullable icons) {
                dispatch_semaphore_signal(sema);
                [allImages addObjectsFromArray:icons];
            }];
            
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        }
        
        if ( completion ) {
            completion(allImages);
        }
    }];
}

- (void)downloadPreferred:(NSURL *)url 
                  options:(FavIconDownloadOptions *)options
               completion:(void (^)(NodeIcon * _Nullable icon))completion {
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
            NSArray<NodeIcon*>* icons = [images map:^id _Nonnull(IMAGE_TYPE_PTR  _Nonnull obj, NSUInteger idx) {
                return [NodeIcon withCustomImage:obj];
            }];
            
            NodeIcon *best = [self getIdealImage:icons options:options];
            
            completion(best);
        }];
#else
        slog(@"WARNWARN: attempt to use FavIcon library when compiled out.");
        completion(nil);
#endif
        
        if (error) {
            slog(@"Error: [%@]", error);
            completion(nil);
        }
    } @catch (NSException *exception) {
        slog(@"Exception in downloadAll: [%@]", exception);
        completion(nil);
    } @finally { }
}

- (void)downloadAll:(NSURL *)url
            options:(FavIconDownloadOptions*)options
         completion:(void (^)(NSArray<NodeIcon*>* _Nullable icons ))completion {
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
            NSArray<NodeIcon*>* icons = [images map:^id _Nonnull(IMAGE_TYPE_PTR  _Nonnull obj, NSUInteger idx) {
                return [NodeIcon withCustomImage:obj];
            }];
            completion(icons);
        }];
#else
        slog(@"WARNWARN: attempt to use FavIcon library when compiled out.");
        completion(@[]);
#endif
        
        if (error) {
            slog(@"Error: [%@]", error);
            completion(@[]);
        }
    } @catch (NSException *exception) {
        slog(@"Exception in downloadAll: [%@]", exception);
        completion(@[]);
    } @finally {    }
}

- (NodeIcon*)getIdealImage:(NSArray<NodeIcon*> *)images
                   options:(FavIconDownloadOptions *)options {
    NSArray<NodeIcon*> *sorted = [self getSortedImages:images options:options];
    
    
    
    return [sorted firstOrDefault:^BOOL(NodeIcon * _Nonnull obj) {
        return obj.estimatedStorageBytes < options.maxSize;
    }];
}

- (NSArray<NodeIcon*>*)getSortedImages:(NSArray<NodeIcon*> *)images
                               options:(FavIconDownloadOptions *)options {
    NSArray<NodeIcon*>* sorted = [images sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        NodeIcon* a = obj1;
        NodeIcon* b = obj2;
         
        NSInteger sizeA = a.estimatedStorageBytes;
        NSInteger sizeB = b.estimatedStorageBytes;
        
        NSInteger disA = abs( (int) (sizeA - options.idealSize )) / 1024;
        NSInteger disB = abs( (int) (sizeB - options.idealSize )) / 1024;
        
        int distanceA = abs( (int) (a.customIconWidth - options.idealDimension));
        int distanceB = abs( (int) (b.customIconWidth - options.idealDimension));

        double cartesian1 = sqrt(pow(distanceA, 2) + pow(disA, 2));
        double cartesian2 = sqrt(pow(distanceB, 2) + pow(disB, 2));
           
        return cartesian1 == cartesian2 ? NSOrderedSame : (cartesian1 < cartesian2 ? NSOrderedAscending : NSOrderedDescending );
    }];
    
#ifdef DEBUG
    slog(@"=============== 🟢 Sorted ================= ");
    for (NodeIcon* icon in sorted) {
        int fileSizeScore = abs( (int) (icon.estimatedStorageBytes - options.idealSize )) / 1024;
        int dimensionScore = abs( (int) (icon.customIconWidth - options.idealDimension));
        double cartesian = sqrt(pow(dimensionScore, 2) + pow(fileSizeScore, 2));
        
        slog(@"%dx%d - %@ - (fileSizeScore=%d, dimensionScore=%d, score=%f )", (int)icon.customIconWidth, (int)icon.customIconHeight, friendlyFileSizeString(icon.estimatedStorageBytes), fileSizeScore, dimensionScore, cartesian);
    }
    slog(@"=========================================== ");
#endif
    
    return sorted;
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
