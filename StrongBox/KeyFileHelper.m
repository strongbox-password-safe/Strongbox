//
//  KeyFileHelper.m
//  Strongbox
//
//  Created by Mark on 14/12/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "KeyFileHelper.h"
#import "KeyFileParser.h"
#import "BookmarksHelper.h"

@implementation KeyFileHelper

NSData* getKeyFileDigest(NSString* keyFileBookmark, NSData* onceOffKeyFileData, DatabaseFormat format, NSError** error) {
    NSData* keyFileData = getKeyFileData(keyFileBookmark, onceOffKeyFileData, error);
    
    NSData *keyFileDigest = keyFileData ? [KeyFileParser getKeyFileDigestFromFileData:keyFileData checkForXml:format != kKeePass1] : nil;

    return keyFileDigest;
}

NSData* getKeyFileData(NSString*_Nullable keyFileBookmark, NSData*_Nullable onceOffKeyFileData, NSError** error) {
    NSData* keyFileData = nil;
    
    if (keyFileBookmark) {
        NSString* updated;
        NSURL* keyFileUrl = [BookmarksHelper getUrlFromBookmark:keyFileBookmark readOnly:YES updatedBookmark:&updated error:error];
        if (keyFileUrl) {
            keyFileData = [NSData dataWithContentsOfURL:keyFileUrl options:kNilOptions error:error];
        }
    }
    else if (onceOffKeyFileData) {
        keyFileData = onceOffKeyFileData;
    }
    
    return keyFileData;
}

@end
