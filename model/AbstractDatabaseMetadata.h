//
//  AbstractSafeMetadata.h
//  Strongbox
//
//  Created by Mark on 23/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BasicOrderedDictionary.h"

NS_ASSUME_NONNULL_BEGIN

@protocol AbstractDatabaseMetadata <NSObject>

- (BasicOrderedDictionary<NSString*, NSString*>*)kvpForUi;

@end

NS_ASSUME_NONNULL_END
