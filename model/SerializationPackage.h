//
//  SerializationPackage.h
//  Strongbox
//
//  Created by Mark on 25/08/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KeePassAttachmentAbstractionLayer.h"

NS_ASSUME_NONNULL_BEGIN

@interface SerializationPackage : NSObject

@property NSMutableSet<NSNumber*>* usedAttachmentIndices;
@property NSMutableSet<NSUUID*>* usedCustomIcons;

@end

NS_ASSUME_NONNULL_END
