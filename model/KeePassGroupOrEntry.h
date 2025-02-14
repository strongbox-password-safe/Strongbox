//
//  KeePassGroupOrEntry.h
//  Strongbox
//
//  Created by Strongbox on 23/10/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

@protocol KeePassGroupOrEntry <NSObject>

@property (nonatomic, readonly) BOOL isGroup;

@end

NS_ASSUME_NONNULL_END
