//
//  KeyFileParser.h
//  Strongbox
//
//  Created by Mark on 04/12/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DatabaseFormat.h"

NS_ASSUME_NONNULL_BEGIN

@interface KeyFileParser : NSObject

+ (nullable NSData *)getNonePerformantKeyFileDigest:(NSData*)data
                                        checkForXml:(BOOL)checkForXml; 

+ (nullable NSData *)getDigestFromSources:(NSString*_Nullable)keyFileBookmark
                       onceOffKeyFileData:(NSData*_Nullable)onceOffKeyFileData
                              streamLarge:(BOOL)streamLarge
                                   format:(DatabaseFormat)format
                                    error:(NSError**)error;

@end

NS_ASSUME_NONNULL_END
