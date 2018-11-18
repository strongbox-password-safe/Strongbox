//
//  PwSafeMetadata.h
//  Strongbox
//
//  Created by Mark on 23/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "AbstractDatabaseMetadata.h"

static const NSInteger kDefaultVersionMajor = 0x03;
static const NSInteger kDefaultVersionMinor = 0x0D;

NS_ASSUME_NONNULL_BEGIN

@interface PwSafeMetadata : NSObject<AbstractDatabaseMetadata>

- (instancetype)init;
- (instancetype)initWithVersion:(NSString*)version NS_DESIGNATED_INITIALIZER;

@property (nonatomic, nullable) NSDate *lastUpdateTime;
@property (nonatomic, nullable) NSString *lastUpdateUser;
@property (nonatomic, nullable) NSString *lastUpdateHost;
@property (nonatomic, nullable) NSString *lastUpdateApp;
@property (nonatomic) NSInteger keyStretchIterations;
@property (nonatomic, readonly) NSString * _Nonnull version;

@end

NS_ASSUME_NONNULL_END
