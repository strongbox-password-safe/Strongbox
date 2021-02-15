//
//  StorageBrowserItem.m
//  StrongBox
//
//  Created by Mark on 26/05/2017.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "StorageBrowserItem.h"

@implementation StorageBrowserItem

+ (instancetype)itemWithName:(NSString*)name identifier:(NSString*)identifier folder:(BOOL)folder providerData:(id)providerData {
    return [[StorageBrowserItem alloc] initWithName:name identifier:identifier folder:folder providerData:providerData];
}

- (instancetype)initWithName:(NSString*)name identifier:(NSString*)identifier folder:(BOOL)folder providerData:(id)providerData {
    self = [super init];
    if (self) {
        self.name = name;
        self.identifier = identifier;
        self.folder = folder;
        self.providerData = providerData;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ [folder: %d] - [%@] - providerData = [%@]", self.name, self.folder, self.identifier, self.providerData];
}

@end
