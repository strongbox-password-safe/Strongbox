//
//  KeyFileParser.h
//  Strongbox
//
//  Created by Mark on 04/12/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DatabaseFormat.h"
#import "KeyFile.h"

NS_ASSUME_NONNULL_BEGIN

@interface KeyFileManagement : NSObject

+ (KeyFile*)generateNewV2;

+ (nullable NSData *)getNonePerformantKeyFileDigest:(NSData*)data
                                        checkForXml:(BOOL)checkForXml; 

+ (NSData *)getDigestFromBookmark:(NSString*_Nullable)keyFileBookmark
                      fallbackUrl:(NSURL*_Nullable)fallbackUrl
                  keyFileFileName:(NSString*_Nullable)keyFileFileName
                           format:(DatabaseFormat)format
               resolvedKeyFileUrl:(NSURL*_Nullable*_Nullable)resolvedKeyFileUrl
                  updatedBookmark:(NSString*_Nullable*_Nullable)updatedBookmark
                            error:(NSError **)error;

+ (nullable NSData *)getDigestFromSources:(NSString*_Nullable)keyFileBookmark
                              fallbackUrl:(NSURL*_Nullable)fallbackUrl
                          keyFileFileName:(NSString*_Nullable)keyFileFileName
                       onceOffKeyFileData:(NSData*_Nullable)onceOffKeyFileData
                                   format:(DatabaseFormat)format
                       resolvedKeyFileUrl:(NSURL*_Nullable*_Nullable)resolvedKeyFileUrl
                          updatedBookmark:(NSString*_Nullable*_Nullable)updatedBookmark
                                    error:(NSError**)error;

@end

NS_ASSUME_NONNULL_END
