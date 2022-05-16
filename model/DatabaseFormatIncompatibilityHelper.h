//
//  DatabaseFormatIncompatibilityHelper.h
//  MacBox
//
//  Created by Strongbox on 28/07/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Node.h"
#import "DatabaseFormat.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^IncompatibilityConfirmChangesResultBlock)(BOOL go);
typedef void (^IncompatibilityConfirmChangesBlock)(NSString*_Nullable confirmMessage, IncompatibilityConfirmChangesResultBlock resultBlock);
typedef void (^IncompatibilityCompletionBlock)(BOOL go, NSArray<Node*>*_Nullable compatibleFilteredNodes);


@interface DatabaseFormatIncompatibilityHelper : NSObject

+ (void)processFormatIncompatibilities:(NSArray<Node*>*)nodes
                destinationIsRootGroup:(BOOL)destinationIsRootGroup
                          sourceFormat:(DatabaseFormat)sourceFormat
                     destinationFormat:(DatabaseFormat)destinationFormat
                   confirmChangesBlock:(IncompatibilityConfirmChangesBlock)confirmChangesBlock
                            completion:(IncompatibilityCompletionBlock)completion;

+ (NSArray<Node*>*)processPasswordSafeToKeePass2:(NSArray<Node*>*)nodes;

@end

NS_ASSUME_NONNULL_END
