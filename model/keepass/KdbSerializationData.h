//
//  KdbSerializationData.h
//  Strongbox
//
//  Created by Mark on 08/11/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KdbGroup.h"
#import "KdbEntry.h"

NS_ASSUME_NONNULL_BEGIN

@interface KdbSerializationData : NSObject

@property NSMutableArray<KdbGroup*>* groups;
@property NSMutableArray<KdbEntry*>* entries;
@property NSMutableArray<KdbEntry*>* metaEntries;
@property uint32_t version;
@property uint32_t flags;
@property uint32_t transformRounds;

@end

NS_ASSUME_NONNULL_END
