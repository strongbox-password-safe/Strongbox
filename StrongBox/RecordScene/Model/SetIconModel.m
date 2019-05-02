//
//  SetIconModel.m
//  Strongbox-iOS
//
//  Created by Mark on 25/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "SetIconModel.h"

@implementation SetIconModel

+ (instancetype)setIconModelWith:(NSNumber *)index
                      customUuid:(NSUUID *)customUuid
                     customImage:(UIImage *)customImage {
    return [[SetIconModel alloc] initWithIndex:index customUuid:customUuid customImage:customImage];
}

- (instancetype)initWithIndex:(NSNumber *)index customUuid:(NSUUID *)customUuid customImage:(UIImage *)customImage {
    self = [super init];
    
    if (self) {
        _index = index;
        _customUuid = customUuid;
        _customImage = customImage;
    }
    return self;
}
    
@end
