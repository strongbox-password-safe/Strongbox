//
//  WordList.h
//  Strongbox
//
//  Created by Strongbox on 14/05/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM (NSInteger, WordListCategory) {
    kWordListCategoryStandard,
    kWordListCategoryFandom,
    kWordListCategoryLanguages,
};

@interface WordList : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)named:(NSString*)name withKey:(NSString*)withKey withCategory:(WordListCategory)withCategory;

@property (readonly) NSString* key;
@property (readonly) NSString* name;
@property (readonly) WordListCategory category;

@end

NS_ASSUME_NONNULL_END
