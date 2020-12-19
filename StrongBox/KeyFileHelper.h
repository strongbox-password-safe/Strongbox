//
//  KeyFileHelper.h
//  Strongbox
//
//  Created by Mark on 14/12/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DatabaseFormat.h"

NS_ASSUME_NONNULL_BEGIN

@interface KeyFileHelper : NSObject

NSData*_Nullable getKeyFileDigest(NSString* keyFileBookmark, NSData* onceOffKeyFileData, DatabaseFormat format, NSError** error);
NSData*_Nullable getKeyFileData(NSString* keyFileBookmark, NSData* onceOffKeyFileData, NSError** error);

@end

NS_ASSUME_NONNULL_END
