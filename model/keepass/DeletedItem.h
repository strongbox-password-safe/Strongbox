//
//  DeletedItem.h
//  Strongbox
//
//  Created by Strongbox on 14/05/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DeletedItem : NSObject

@property NSUUID* uuid;
@property NSDate* date;

+ (instancetype)uuid:(NSUUID*)uuid;
+ (instancetype)uuid:(NSUUID*)uuid date:(NSDate*)date;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithUuid:(NSUUID*)uuid date:(NSDate*)date NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
