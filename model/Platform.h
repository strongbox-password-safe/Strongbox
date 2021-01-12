//
//  Platform.h
//  Strongbox
//
//  Created by Mark on 14/12/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Platform : NSObject

@property (class, readonly) BOOL isSimulator;
@property (class, readonly) BOOL iOS13Available;
@property (class, readonly) BOOL iOS14Available;

@end

NS_ASSUME_NONNULL_END
