//
//  KeepassMetaDataAndNodeModel.h
//  Strongbox
//
//  Created by Mark on 23/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Node.h"
#import "KeePassDatabaseMetadata.h"

NS_ASSUME_NONNULL_BEGIN

@interface KeepassMetaDataAndNodeModel : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithMetadata:(KeePassDatabaseMetadata*)metadata nodeModel:(Node*)nodeModel NS_DESIGNATED_INITIALIZER;

@property (nonatomic) KeePassDatabaseMetadata* metadata;
@property (nonatomic) Node* rootNode;

@end

NS_ASSUME_NONNULL_END
