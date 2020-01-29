//
//  BookmarksHelper.h
//  Strongbox
//
//  Created by Mark on 21/01/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BookmarksHelper : NSObject

+ (NSString*_Nullable)getBookmarkFromUrl:(NSURL*)url error:(NSError*_Nonnull*_Nonnull)error;
+ (NSURL*_Nullable)getExpressUrlFromBookmark:(NSString *)bookmark;
+ (NSURL*_Nullable)getUrlFromBookmark:(NSString*)bookmarkInB64 updatedBookmark:(NSString*_Nonnull*_Nonnull)updatedBookmark error:(NSError*_Nonnull*_Nonnull)error;
+ (NSData*_Nullable)dataWithContentsOfBookmark:(NSString*)bookmarkInB64 error:(NSError*_Nonnull*_Nonnull)error;

@end

NS_ASSUME_NONNULL_END
