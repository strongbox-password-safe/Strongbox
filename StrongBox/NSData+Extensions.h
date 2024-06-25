//
//  NSData__Extensions.h
//  Strongbox
//
//  Created by Strongbox on 02/05/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSData (Extensions)

+ (instancetype _Nullable)dataWithContentsOfStream:(NSInputStream*)inputStream;

@property (readonly) NSString* base64String;
@property (readonly) NSString* upperHexString;
@property (readonly) NSData* sha1;
@property (readonly) NSData* sha256;

@end

NS_ASSUME_NONNULL_END
