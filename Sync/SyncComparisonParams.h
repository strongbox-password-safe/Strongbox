//
//  SyncComparisonParams.h
//  Strongbox
//
//  Created by Strongbox on 05/12/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NodeFileAttachment.h"

NS_ASSUME_NONNULL_BEGIN

typedef BOOL (^NodeAttachmentCompareBlock)(NodeFileAttachment* a, NodeFileAttachment* b);

@interface SyncComparisonParams : NSObject

@property NodeAttachmentCompareBlock compareNodeAttachmentBlock;

@end

NS_ASSUME_NONNULL_END
