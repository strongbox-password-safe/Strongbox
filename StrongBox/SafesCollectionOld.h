//
//  SafesCollection.h
//  StrongBox
//
//  Created by Mark on 22/11/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeMetaData.h"

@interface SafesCollectionOld : NSObject

+ (instancetype _Nullable)sharedInstance;

@property (nonatomic, nonnull, readonly) NSArray<SafeMetaData*> *sortedSafes;

@end
