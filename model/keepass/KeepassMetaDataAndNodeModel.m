//
//  KeepassMetaDataAndNodeModel.m
//  Strongbox
//
//  Created by Mark on 23/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "KeepassMetaDataAndNodeModel.h"

@implementation KeepassMetaDataAndNodeModel

- (instancetype)initWithMetadata:(KeePassDatabaseMetadata*)metadata nodeModel:(Node*)nodeModel {
    if (self = [super init]) {
        self.metadata = metadata;
        self.rootNode = nodeModel;
    }
    
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"{\nmetadata = [%@]\nrootNode = [%@]\n}", self.metadata, self.rootNode];
}
@end
