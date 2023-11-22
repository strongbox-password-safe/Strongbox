//
//  FavIconDownloadOptions.m
//  Strongbox
//
//  Created by Mark on 28/11/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "FavIconDownloadOptions.h"

static NSInteger kDefaultIdealSize = 4 * 1024;
static NSInteger kDefaultMaxSize = 25 * 1024;
static NSInteger kDefaultIdealDimension = 128;

@implementation FavIconDownloadOptions

+ (instancetype)defaults {
    return [[FavIconDownloadOptions alloc] init];
}

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.checkCommonFavIconFiles = NO;
        self.duckDuckGo = YES;
        self.domainOnly = YES;
        self.scanHtml = YES;
        self.google = NO;
        self.ignoreInvalidSSLCerts = NO;
        
        self.idealSize = kDefaultIdealSize;
        self.maxSize = kDefaultMaxSize;
        self.idealDimension = kDefaultIdealDimension;
    }
    
    return self;
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

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeBool:self.checkCommonFavIconFiles forKey:@"checkCommonFavIconFiles"];
    [encoder encodeBool:self.duckDuckGo forKey:@"duckDuckGo"];
    [encoder encodeBool:self.domainOnly forKey:@"domainOnly"];
    [encoder encodeBool:self.google forKey:@"google"];
    [encoder encodeBool:self.scanHtml forKey:@"scanHtml"];
    [encoder encodeBool:self.ignoreInvalidSSLCerts forKey:@"ignoreInvalidSSLCerts"];
    
    [encoder encodeInteger:self.maxSize forKey:@"maxSize"];
    [encoder encodeInteger:self.idealSize forKey:@"idealSize"];
    [encoder encodeInteger:self.idealDimension forKey:@"idealDimension"];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if((self = [self init])) {
        self.checkCommonFavIconFiles = [decoder decodeBoolForKey:@"checkCommonFavIconFiles"];
        self.duckDuckGo = [decoder decodeBoolForKey:@"duckDuckGo"];
        self.domainOnly = [decoder decodeBoolForKey:@"domainOnly"];
        self.google = [decoder decodeBoolForKey:@"google"];
        self.scanHtml = [decoder decodeBoolForKey:@"scanHtml"];
        self.ignoreInvalidSSLCerts = [decoder decodeBoolForKey:@"ignoreInvalidSSLCerts"];
        
        if ( [decoder containsValueForKey:@"maxSize"] ) {
            self.maxSize = [decoder decodeIntegerForKey:@"maxSize"];
        }
        else {
            self.maxSize = kDefaultMaxSize;
        }
        
        if ( [decoder containsValueForKey:@"idealSize"] ) {
            self.idealSize = [decoder decodeIntegerForKey:@"idealSize"];
        }
        else {
            self.idealSize = kDefaultIdealSize;
        }
        
        if ( [decoder containsValueForKey:@"idealDimension"] ) {
            self.idealDimension = [decoder decodeIntegerForKey:@"idealDimension"];
        }
        else {
            self.idealDimension = kDefaultIdealDimension;
        }
    }

    return self;
}

- (BOOL)isValid { 
    return self.duckDuckGo || self.google || self.scanHtml || self.checkCommonFavIconFiles;
}

@end
