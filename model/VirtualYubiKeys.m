//
//  VirtualYubiKeys.m
//  Strongbox
//
//  Created by Strongbox on 16/10/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "VirtualYubiKeys.h"
#import "NSArray+Extensions.h"

#if TARGET_OS_IPHONE
#import "StrongboxiOSFilesManager.h"
#else
#import "StrongboxMacFilesManager.h"
#endif

static NSString* const kConfigFilename = @"virtual-yubikeys.json";
NSString* _Nonnull const kVirtualYubiKeysChangedNotification = @"VirtualYubiKeysChangedNotification";

@implementation VirtualYubiKeys

+ (instancetype)sharedInstance {
    static VirtualYubiKeys *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[VirtualYubiKeys alloc] init];
    });
    return sharedInstance;
}

- (NSMutableArray<VirtualYubiKey*>*)deserialize {
    NSMutableArray<VirtualYubiKey*> *ret = NSMutableArray.array;
    
    NSURL* fileUrl = [StrongboxFilesManager.sharedInstance.preferencesDirectory URLByAppendingPathComponent:kConfigFilename];
    
    NSError* error;
    __block NSError* readError;
    __block NSData* json = nil;
    NSFileCoordinator *fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
    
    [fileCoordinator coordinateReadingItemAtURL:fileUrl
                                        options:kNilOptions
                                          error:&error
                                     byAccessor:^(NSURL * _Nonnull newURL) {
        json = [NSData dataWithContentsOfURL:fileUrl options:kNilOptions error:&readError];
    }];
    
    if (!json || error || readError) {
        if ( readError && readError.code == NSFileReadNoSuchFileError ) return ret;
        
        slog(@"🔴 Error reading file for Virtual Hardware Keys: [%@] - [%@]", error, readError);
        return ret;
    }

    NSArray* jsonArray = [NSJSONSerialization JSONObjectWithData:json options:kNilOptions error:&error];

    if (error) {
        slog(@"Error getting json Virtual Hardware Keys: [%@]", error);
        return ret;
    }

    for (NSDictionary* jsonDatabase in jsonArray) {
        VirtualYubiKey* database = [VirtualYubiKey fromJsonSerializationDictionary:jsonDatabase];
        [ret addObject:database];
    }
    
    return ret;
}

- (void)serialize:(NSArray<VirtualYubiKey*>*)list {
    NSMutableArray<NSDictionary*>* jsonArray = NSMutableArray.array;

    for (VirtualYubiKey* key in list) {
        NSDictionary* jsonDict = [key getJsonSerializationDictionary];
        [jsonArray addObject:jsonDict];
    }
    
    NSError* error;
    NSUInteger options = NSJSONWritingPrettyPrinted;
    options |= NSJSONWritingSortedKeys;
    
    NSData* json = [NSJSONSerialization dataWithJSONObject:jsonArray options:options error:&error];

    if (error) {
        slog(@"Error getting json for databases: [%@]", error);
        return;
    }

    NSURL* fileUrl = [StrongboxFilesManager.sharedInstance.preferencesDirectory URLByAppendingPathComponent:kConfigFilename];

    NSFileCoordinator *fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
    __block NSError *writeError = nil;
    __block BOOL success = NO;
    [fileCoordinator coordinateWritingItemAtURL:fileUrl
                                        options:0
                                          error:&error
                                     byAccessor:^(NSURL *newURL) {
        success = [json writeToURL:newURL options:NSDataWritingAtomic error:&writeError];
    }];

    if (!success || error || writeError) {
        slog(@"Error writing Virtual Hardware Keys file: [%@]-[%@]", error, writeError);
        return;
    }
    else {
        [NSNotificationCenter.defaultCenter postNotificationName:kVirtualYubiKeysChangedNotification object:nil];
    }
}

- (VirtualYubiKey*)getById:(NSString*)identifier {
    NSMutableArray<VirtualYubiKey*>* list = [self deserialize];

    return [list firstOrDefault:^BOOL(VirtualYubiKey * _Nonnull obj) {
        return [obj.identifier isEqualToString:identifier];
    }];
}

- (void)addKey:(VirtualYubiKey*)key {
    NSMutableArray<VirtualYubiKey*>* list = [self deserialize];

    [list addObject:key];
    
    [self serialize:list];
}

- (void)deleteKey:(NSString *)identifier {
    NSMutableArray<VirtualYubiKey*>* list = [self deserialize];

    VirtualYubiKey* key = [list firstOrDefault:^BOOL(VirtualYubiKey * _Nonnull obj) {
        return [obj.identifier isEqualToString:identifier];
    }];

    [list removeObject:key];
    
    [key clearSecret];
    
    [self serialize:list];
}

- (NSArray<VirtualYubiKey*>*)snapshot {
    NSMutableArray<VirtualYubiKey*>* list = [self deserialize];

    return list.copy;
}

@end
