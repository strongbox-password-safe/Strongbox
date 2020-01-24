//
//  BookmarksHelper.m
//  Strongbox
//
//  Created by Mark on 21/01/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "BookmarksHelper.h"
#import "Utils.h"

@implementation BookmarksHelper

+ (NSString *)getBookmarkFromUrl:(NSURL *)url error:(NSError *_Nonnull*)error {
    NSData *bookmark = [url bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
                     includingResourceValuesForKeys:nil
                                      relativeToURL:nil
                                              error:error];
    if (!bookmark) {
        NSLog(@"Error while creating bookmark for URL (%@): %@", url, *error);
        return nil;
    }
    
    return [bookmark base64EncodedStringWithOptions:kNilOptions];
}

+ (NSURL *)getUrlFromBookmark:(NSString *)bookmarkInB64 updatedBookmark:(NSString *_Nonnull*)updatedBookmark error:(NSError *_Nonnull*)error {
    BOOL bookmarkDataIsStale;

    NSData* bookmarkData = [[NSData alloc] initWithBase64EncodedString:bookmarkInB64 options:kNilOptions];
    
    if(bookmarkData == nil) {
        *error = [Utils createNSError:@"Could not decode bookmark." errorCode:-1];
        return nil;
    }
    
    NSURL* bookmarkFileURL = [NSURL URLByResolvingBookmarkData:bookmarkData
                                                       options:NSURLBookmarkResolutionWithSecurityScope
                                                 relativeToURL:nil
                                           bookmarkDataIsStale:&bookmarkDataIsStale
                                                         error:error];
    if(!bookmarkFileURL) {
        NSLog(@"Could not get bookmark URL.");
        return nil;
    }
    
    if(bookmarkDataIsStale) {
        if ([bookmarkFileURL startAccessingSecurityScopedResource]) {
            NSLog(@"Regenerating Bookmark -> bookmarkDataIsStale = %d => [%@]", bookmarkDataIsStale, bookmarkFileURL);
            
            NSString* fileIdentifier = [BookmarksHelper getBookmarkFromUrl:bookmarkFileURL error:error];
            
            [bookmarkFileURL stopAccessingSecurityScopedResource];
            
            if(!fileIdentifier) {
                NSLog(@"Error regenerating: [%@]", *error);
                return nil;
            }

            *updatedBookmark = fileIdentifier;
            return bookmarkFileURL;
        }
        else {
            NSLog(@"Regen Bookmark security failed....");
            *error = [Utils createNSError:@"Regen Bookmark security failed." errorCode:-1];
            return nil;
        }
    }

    return bookmarkFileURL;
}

+ (NSData *)dataWithContentsOfBookmark:(NSString *)bookmarkInB64 error:(NSError**)error {
    NSString* updatedBookmark;
    
    NSURL* url = [BookmarksHelper getUrlFromBookmark:bookmarkInB64 updatedBookmark:&updatedBookmark error:error];

    if(url && [url startAccessingSecurityScopedResource]) {
        //NSLog(@"Reading File at [%@]", url);
        NSData* ret = [NSData dataWithContentsOfURL:url options:kNilOptions error:error];
        
        [url stopAccessingSecurityScopedResource];
        
        return ret;
    }
    else {
        NSLog(@"Could not read file... [%@]", *error);
    }
    
    return nil;
}

@end
