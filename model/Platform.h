//
//  Platform.h
//  Strongbox
//
//  Created by Mark on 14/12/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Platform : NSObject

@property (class, readonly) BOOL isSimulator;

@end

NS_ASSUME_NONNULL_END
