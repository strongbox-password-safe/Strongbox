//
//  KeyFileHelper.h
//  Strongbox
//
//  Created by Mark on 14/12/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DatabaseFormat.h"

NS_ASSUME_NONNULL_BEGIN

@interface KeyFileHelper : NSObject

NSData*_Nullable getKeyFileDigest(NSString*_Nullable keyFileBookmark, NSData*_Nullable onceOffKeyFileData, DatabaseFormat format, NSError** error);
NSData*_Nullable getKeyFileData(NSString*_Nullable keyFileBookmark, NSData*_Nullable onceOffKeyFileData, NSError** error);

@end

NS_ASSUME_NONNULL_END
