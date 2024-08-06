//
//  WebDAVConnections.m
//  Strongbox
//
//  Created by Strongbox on 02/08/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "WebDAVConnections.h"
#import "NSArray+Extensions.h"

#if TARGET_OS_IPHONE
#import "StrongboxiOSFilesManager.h"
#else
#import "StrongboxMacFilesManager.h"
#endif

#import "SBLog.h"

static NSString* const kConfigFilename = @"webdav-connections.json";

@implementation WebDAVConnections

+ (instancetype)sharedInstance {
    static WebDAVConnections *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[WebDAVConnections alloc] init];
    });
    return sharedInstance;
}

- (NSMutableArray<WebDAVSessionConfiguration*>*)deserialize {
    NSMutableArray<WebDAVSessionConfiguration*> *ret = NSMutableArray.array;
    
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
        slog(@"Error reading file for WebDAV Connections [%@] - [%@]", error, readError);
        return ret;
    }

    NSArray* jsonArray = [NSJSONSerialization JSONObjectWithData:json options:kNilOptions error:&error];

    if (error) {
        slog(@"Error getting json WebDAV Connections: [%@]", error);
        return ret;
    }

    for (NSDictionary* jsonDatabase in jsonArray) {
        WebDAVSessionConfiguration* database = [WebDAVSessionConfiguration fromSerializationDictionary:jsonDatabase];
        [ret addObject:database];
    }
    
    return ret;
}

- (void)serialize:(NSArray<WebDAVSessionConfiguration*>*)list {
    NSMutableArray<NSDictionary*>* jsonArray = NSMutableArray.array;

    for (WebDAVSessionConfiguration* config in list) {
        NSDictionary* jsonDict = [config serializationDictionary];
        [jsonArray addObject:jsonDict];
    }
    
    NSError* error;
    NSUInteger options = NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys;
    
    NSData* json = [NSJSONSerialization dataWithJSONObject:jsonArray options:options error:&error];

    if (error) {
        slog(@"Error getting json for WebDAV Connections: [%@]", error);
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
        slog(@"Error writing WebDAV Connections file: [%@]-[%@]", error, writeError);
        return;
    }
}

- (WebDAVSessionConfiguration*)getById:(NSString*)identifier {
    NSMutableArray<WebDAVSessionConfiguration*>* list = [self deserialize];

    return [list firstOrDefault:^BOOL(WebDAVSessionConfiguration * _Nonnull obj) {
        return [obj.identifier isEqualToString:identifier];
    }];
}

- (void)addOrUpdate:(WebDAVSessionConfiguration *)connection {
    NSMutableArray<WebDAVSessionConfiguration*>* list = [self deserialize];

    NSInteger index = [list indexOfFirstMatch:^BOOL(WebDAVSessionConfiguration * _Nonnull obj) {
        return [obj.identifier isEqualToString:connection.identifier];
    }];
    
    if ( index != NSNotFound ) {
        [list replaceObjectAtIndex:index withObject:connection];
    }
    else {
        [list addObject:connection];
    }
    
    [self serialize:list];
}

- (void)deleteConnection:(NSString *)identifier {
    NSMutableArray<WebDAVSessionConfiguration*>* list = [self deserialize];

    WebDAVSessionConfiguration* key = [list firstOrDefault:^BOOL(WebDAVSessionConfiguration * _Nonnull obj) {
        return [obj.identifier isEqualToString:identifier];
    }];

    [list removeObject:key];
    
    [key clearKeychainItems];
    
    [self serialize:list];
}

- (NSArray<WebDAVSessionConfiguration*>*)snapshot {
    NSMutableArray<WebDAVSessionConfiguration*>* list = [self deserialize];

    return list.copy;
}

@end
