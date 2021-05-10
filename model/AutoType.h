//
//  AutoType.h
//  Strongbox
//
//  Created by Strongbox on 15/11/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AutoTypeAssociation.h"

NS_ASSUME_NONNULL_BEGIN

@interface AutoType : NSObject

@property BOOL enabled;
@property NSInteger dataTransferObfuscation;
@property (nullable) NSString* defaultSequence;
@property NSArray<AutoTypeAssociation*> *asssociations;

+ (BOOL)isDefault:(AutoType*)autoType;

@end

NS_ASSUME_NONNULL_END
