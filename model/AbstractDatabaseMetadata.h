//
//  AbstractSafeMetadata.h
//  Strongbox
//
//  Created by Mark on 23/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MutableOrderedDictionary.h"

NS_ASSUME_NONNULL_BEGIN

@protocol AbstractDatabaseMetadata <NSObject>

- (MutableOrderedDictionary<NSString*, NSString*>*)kvpForUi;

@property (nonatomic, nullable) NSString* version;
@property (nonatomic, nullable) NSString *generator;

@property (nullable, nonatomic) NSDate* recycleBinChanged;
@property (nullable, nonatomic) NSUUID* recycleBinGroup;
@property BOOL recycleBinEnabled;

@property (nonatomic, nullable) NSNumber *historyMaxItems;
@property (nonatomic, nullable) NSNumber *historyMaxSize;

@property (nonatomic) MutableOrderedDictionary* customData;

@end

NS_ASSUME_NONNULL_END
