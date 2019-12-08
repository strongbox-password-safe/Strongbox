//
//  FavIconDownloadOptions.m
//  Strongbox
//
//  Created by Mark on 28/11/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "FavIconDownloadOptions.h"

@implementation FavIconDownloadOptions

+ (instancetype)defaults {
    return [[FavIconDownloadOptions alloc] init];
}

+ (instancetype)express {
    FavIconDownloadOptions* ret = [[FavIconDownloadOptions alloc] init];

    ret.checkCommonFavIconFiles = NO;
    ret.duckDuckGo = YES;
    ret.domainOnly = YES;
    ret.scanHtml = NO;
    ret.google = NO;
    ret.ignoreInvalidSSLCerts = NO;
    
    return ret;
}

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        self.checkCommonFavIconFiles = NO;
        self.duckDuckGo = YES;
        self.domainOnly = YES;
        self.scanHtml = YES;
        self.google = NO;
        self.ignoreInvalidSSLCerts = NO;
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeBool:self.checkCommonFavIconFiles forKey:@"checkCommonFavIconFiles"];
    [encoder encodeBool:self.duckDuckGo forKey:@"duckDuckGo"];
    [encoder encodeBool:self.domainOnly forKey:@"domainOnly"];
    [encoder encodeBool:self.google forKey:@"google"];
    [encoder encodeBool:self.scanHtml forKey:@"scanHtml"];
    [encoder encodeBool:self.ignoreInvalidSSLCerts forKey:@"ignoreInvalidSSLCerts"];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if((self = [self init])) {
        self.checkCommonFavIconFiles = [decoder decodeBoolForKey:@"checkCommonFavIconFiles"];
        self.duckDuckGo = [decoder decodeBoolForKey:@"duckDuckGo"];
        self.domainOnly = [decoder decodeBoolForKey:@"domainOnly"];
        self.google = [decoder decodeBoolForKey:@"google"];
        self.scanHtml = [decoder decodeBoolForKey:@"scanHtml"];
        self.ignoreInvalidSSLCerts = [decoder decodeBoolForKey:@"ignoreInvalidSSLCerts"];
    }

    return self;
}

- (BOOL)isValid { // At least one of these must be on...
    return self.duckDuckGo || self.google || self.scanHtml || self.checkCommonFavIconFiles;
}

@end
