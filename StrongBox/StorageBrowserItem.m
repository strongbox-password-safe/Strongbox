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
    return [[StorageBrowserItem alloc] initWithName:name identifier:identifier folder:folder canNotCreateDatabaseInThisFolder:NO providerData:providerData];
}

+ (nonnull instancetype)itemWithName:(nonnull NSString *)name identifier:(NSString * _Nullable)identifier folder:(BOOL)folder canNotCreateDatabaseInThisFolder:(BOOL)canCreateDatabaseInThisFolder providerData:(id _Nullable)providerData {
    return [[StorageBrowserItem alloc] initWithName:name identifier:identifier folder:folder canNotCreateDatabaseInThisFolder:canCreateDatabaseInThisFolder providerData:providerData];
}

- (instancetype)initWithName:(NSString*)name identifier:(NSString*)identifier folder:(BOOL)folder canNotCreateDatabaseInThisFolder:(BOOL)canNotCreateDatabaseInThisFolder providerData:(id)providerData {
    self = [super init];
    if (self) {
        self.name = name;
        self.identifier = identifier;
        self.folder = folder;
        self.providerData = providerData;
        self.canNotCreateDatabaseInThisFolder = canNotCreateDatabaseInThisFolder;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ [folder: %d] - [%@] - providerData = [%@]", self.name, self.folder, self.identifier, self.providerData];
}


@end
