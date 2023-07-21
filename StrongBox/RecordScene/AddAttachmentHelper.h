//
//  AddAttachmentHelper.h
//  Strongbox-iOS
//
//  Created by Mark on 25/04/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "KeePassAttachmentAbstractionLayer.h"

NS_ASSUME_NONNULL_BEGIN

extern const int kMaxRecommendedAttachmentSize;

@interface AddAttachmentHelper : NSObject

+ (instancetype)sharedInstance;

- (void)beginAddAttachmentUi:(UIViewController*)vc
               usedFilenames:(NSSet<NSString*>*)usedFilenames
                       onAdd:(void(^)(NSString* filename, KeePassAttachmentAbstractionLayer* databaseAttachment))onAdd;

@end

NS_ASSUME_NONNULL_END
