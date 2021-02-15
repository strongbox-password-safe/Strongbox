//
//  BookmarksHelper.h
//  Strongbox
//
//  Created by Mark on 21/01/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BookmarksHelper : NSObject

+ (NSData*_Nullable)getBookmarkDataFromUrl:(NSURL *)url error:(NSError *_Nonnull*_Nonnull)error;
+ (NSData*_Nullable)getBookmarkDataFromUrl:(NSURL *)url readOnly:(BOOL)readOnly error:(NSError *_Nonnull*_Nonnull)error;
+ (NSString*_Nullable)getBookmarkFromUrl:(NSURL*)url readOnly:(BOOL)readOnly error:(NSError*_Nonnull*_Nonnull)error;

+ (NSURL*_Nullable)getUrlFromBookmarkData:(NSData*)bookmark updatedBookmark:(NSData*_Nonnull*_Nonnull)updatedBookmark error:(NSError*_Nonnull*_Nonnull)error;
+ (NSURL*_Nullable)getUrlFromBookmarkData:(NSData*)bookmark readOnly:(BOOL)readOnly updatedBookmark:(NSData*_Nonnull*_Nonnull)updatedBookmark error:(NSError*_Nonnull*_Nonnull)error;
+ (NSURL*_Nullable)getUrlFromBookmark:(NSString*)bookmarkInB64 readOnly:(BOOL)readOnly updatedBookmark:(NSString*_Nonnull*_Nonnull)updatedBookmark error:(NSError*_Nonnull*_Nonnull)error;

+ (NSURL*_Nullable)getExpressUrlFromBookmark:(NSString *)bookmark;
+ (NSURL*_Nullable)getExpressReadOnlyUrlFromBookmark:(NSString *)bookmark;

+ (NSData*_Nullable)dataWithContentsOfBookmark:(NSString*)bookmarkInB64 error:(NSError*_Nonnull*_Nonnull)error;

@end

NS_ASSUME_NONNULL_END
