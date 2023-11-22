//
//  FavIconDownloadOptions.h
//  Strongbox
//
//  Created by Mark on 28/11/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FavIconDownloadOptions : NSObject

+ (instancetype)defaults;
+ (instancetype)express;

@property BOOL checkCommonFavIconFiles;
@property BOOL duckDuckGo;
@property BOOL domainOnly;
@property BOOL google;
@property BOOL scanHtml;
@property BOOL ignoreInvalidSSLCerts;

@property NSInteger idealSize;
@property NSInteger maxSize;
@property NSInteger idealDimension;

@property (readonly) BOOL isValid;

@end

NS_ASSUME_NONNULL_END
