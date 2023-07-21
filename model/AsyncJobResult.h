//
//  AsyncUpdateResult.h
//  Strongbox
//
//  Created by Strongbox on 29/03/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AsyncJobResult : NSObject

@property NSString* databaseUuid;
@property BOOL success;
@property BOOL userCancelled;
@property BOOL userInteractionRequired;
@property BOOL localWasChanged;
@property (nullable) NSError* error;

@end

NS_ASSUME_NONNULL_END
