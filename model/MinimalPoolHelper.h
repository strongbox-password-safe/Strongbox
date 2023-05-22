//
//  AttachmentsHelper.h
//  Strongbox
//
//  Created by Strongbox on 22/12/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Node.h"

NS_ASSUME_NONNULL_BEGIN

@interface MinimalPoolHelper : NSObject

+ (NSArray<KeePassAttachmentAbstractionLayer*>*)getMinimalAttachmentPool:(Node*)rootNode;

@end

NS_ASSUME_NONNULL_END
