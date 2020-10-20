//
//  NSString__Extensions.h
//  Strongbox
//
//  Created by Strongbox on 02/05/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (Extensions)

@property (readonly) NSData* sha1;
@property (readonly) NSData* sha256;

@property (readonly) NSString* trimmed;
@property (readonly) NSArray<NSString*>* lines;

@property (readonly, nullable) NSURL* urlExtendedParse;

@property (readonly) BOOL isHexString;

@end

NS_ASSUME_NONNULL_END
