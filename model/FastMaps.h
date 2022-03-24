//
//  FastMaps.h
//  MacBox
//
//  Created by Strongbox on 09/03/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ConcurrentMutableDictionary.h"
#import "ConcurrentMutableDictionary.h"
#import "Node.h"

NS_ASSUME_NONNULL_BEGIN

@interface FastMaps : NSObject

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithUuidMap:(NSDictionary<NSUUID*, Node*>*)uuidMap
                withExpiryDates:(NSSet<NSUUID*>*)withExpiryDates
                withAttachments:(NSSet<NSUUID*>*)withAttachments
                      withTotps:(NSSet<NSUUID*>*)withTotps
                         tagMap:(NSDictionary<NSString*, NSSet<NSUUID*>*>* )tagMap
                    usernameSet:(NSCountedSet<NSString*> *)usernameSet
                       emailSet:(NSCountedSet<NSString*> *)emailSet
                         urlSet:(NSCountedSet<NSString*> *)urlSet
              customFieldKeySet:(NSCountedSet<NSString*> *)customFieldKeySet;

@property (readonly) NSDictionary<NSUUID*, Node*>* uuidMap;
@property (readonly) NSSet<NSUUID*> *withExpiryDates;
@property (readonly) NSSet<NSUUID*> *withAttachments;
@property (readonly) NSSet<NSUUID*> *withTotps;
@property (readonly) NSDictionary<NSString*, NSSet<NSUUID*>*>* tagMap;
@property (readonly) NSCountedSet<NSString*> *usernameSet;
@property (readonly) NSCountedSet<NSString*> *emailSet;
@property (readonly) NSCountedSet<NSString*> *urlSet;
@property (readonly) NSCountedSet<NSString*> *customFieldKeySet;

@end

NS_ASSUME_NONNULL_END
