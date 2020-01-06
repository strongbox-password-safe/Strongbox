//
//  CustomIconsRationalizer.h
//  Strongbox
//
//  Created by Mark on 22/12/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Node.h"

NS_ASSUME_NONNULL_BEGIN

@interface CustomIconsRationalizer : NSObject

+ (NSMutableDictionary<NSUUID*, NSData*>*)rationalize:(NSDictionary<NSUUID*, NSData*>*)customIcons root:(Node *)root;

@end

NS_ASSUME_NONNULL_END
