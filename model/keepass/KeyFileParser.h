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

+ (NSData *)getDigestFromBookmark:(NSString*_Nullable)keyFileBookmark
                  keyFileFileName:(NSString*_Nullable)keyFileFileName
                           format:(DatabaseFormat)format
                            error:(NSError **)error;

+ (nullable NSData *)getDigestFromSources:(NSString*_Nullable)keyFileBookmark
                          keyFileFileName:(NSString*_Nullable)keyFileFileName
                       onceOffKeyFileData:(NSData*_Nullable)onceOffKeyFileData
                                   format:(DatabaseFormat)format
                                    error:(NSError**)error;

@end

NS_ASSUME_NONNULL_END
