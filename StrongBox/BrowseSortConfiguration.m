//
//  BrowseSortConfiguration.m
//  Strongbox
//
//  Created by Strongbox on 30/12/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import "BrowseSortConfiguration.h"

@implementation BrowseSortConfiguration

+ (instancetype)defaults {
    BrowseSortConfiguration* config = [[BrowseSortConfiguration alloc] init];
    
    config.field = kBrowseSortFieldTitle;
    config.foldersOnTop = YES;
    config.showAlphaIndex = YES;
    
    return config;
}

- (NSDictionary *)getJsonSerializationDictionary {
    return @{
        @"field" : @(self.field),
        @"descending" : @(self.descending),
        @"foldersOnTop" : @(self.foldersOnTop),
        @"showAlphaIndex" : @(self.showAlphaIndex)
    };
}

+ (instancetype)fromJsonSerializationDictionary:(NSDictionary *)jsonDictionary {
    BrowseSortConfiguration* ret = [[BrowseSortConfiguration alloc] init];
    
    NSNumber* numField = jsonDictionary[@"field"];
    NSNumber* numDescending = jsonDictionary[@"descending"];
    NSNumber* numFoldersOnTop = jsonDictionary[@"foldersOnTop"];
    NSNumber* numShowAlphaIndex = jsonDictionary[@"showAlphaIndex"];
    
    ret.field = numField == nil ? kBrowseSortFieldTitle : numField.intValue;
    ret.descending = numDescending == nil ? NO : numDescending.boolValue;
    ret.foldersOnTop = numFoldersOnTop == nil ? YES : numFoldersOnTop.boolValue;
    ret.showAlphaIndex = numShowAlphaIndex == nil ? YES : numShowAlphaIndex.boolValue;
    
    return ret;
}

@end
