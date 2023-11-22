//
//  BrowseSortConfiguration.h
//  Strongbox
//
//  Created by Strongbox on 30/12/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BrowseSortField.h"

NS_ASSUME_NONNULL_BEGIN

@interface BrowseSortConfiguration : NSObject

+ (instancetype)defaults;

@property BOOL descending;
@property BOOL foldersOnTop;
@property BrowseSortField field;
@property BOOL showAlphaIndex;

+ (instancetype)fromJsonSerializationDictionary:(NSDictionary*)jsonDictionary;
- (NSDictionary *)getJsonSerializationDictionary;

@end

NS_ASSUME_NONNULL_END
