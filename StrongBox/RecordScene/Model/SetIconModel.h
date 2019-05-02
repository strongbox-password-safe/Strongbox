//
//  SetIconModel.h
//  Strongbox-iOS
//
//  Created by Mark on 25/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SetIconModel : NSObject

+ (instancetype)setIconModelWith:(NSNumber*_Nullable)index
                      customUuid:(NSUUID*_Nullable)customUuid
                     customImage:(UIImage*_Nullable)customImage;

- (instancetype)init NS_UNAVAILABLE;

@property (readonly) NSNumber* index;
@property (readonly) NSUUID* customUuid;
@property (readonly) UIImage* customImage;

@end

NS_ASSUME_NONNULL_END
