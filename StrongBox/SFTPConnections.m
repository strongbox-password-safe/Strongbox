//
//  SFTPConnections.m
//  Strongbox
//
//  Created by Strongbox on 02/08/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "SFTPConnections.h"
#import "FileManager.h"
#import "NSArray+Extensions.h"

static NSString* const kConfigFilename = @"sftp-connections.json";

@implementation SFTPConnections

+ (instancetype)sharedInstance {
    static SFTPConnections *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[SFTPConnections alloc] init];
    });
    return sharedInstance;
}

- (NSMutableArray<SFTPSessionConfiguration*>*)deserialize {
    NSMutableArray<SFTPSessionConfiguration*> *ret = NSMutableArray.array;
    
    NSURL* fileUrl = [FileManager.sharedInstance.preferencesDirectory URLByAppendingPathComponent:kConfigFilename];
    
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
        NSLog(@"Error reading file for SFTP Connections: [%@] - [%@]", error, readError);
        return ret;
    }

    NSArray* jsonArray = [NSJSONSerialization JSONObjectWithData:json options:kNilOptions error:&error];

    if (error) {
        NSLog(@"Error getting json SFTP Connections: [%@]", error);
        return ret;
    }

    for (NSDictionary* jsonDatabase in jsonArray) {
        SFTPSessionConfiguration* database = [SFTPSessionConfiguration fromSerializationDictionary:jsonDatabase];
        [ret addObject:database];
    }
    
    return ret;
}

- (void)serialize:(NSArray<SFTPSessionConfiguration*>*)list {
    NSMutableArray<NSDictionary*>* jsonArray = NSMutableArray.array;

    for (SFTPSessionConfiguration* connection in list) {
        NSDictionary* jsonDict = [connection serializationDictionary];
        [jsonArray addObject:jsonDict];
    }
    
    NSError* error;
    NSUInteger options = NSJSONWritingPrettyPrinted;

#if TARGET_OS_IPHONE
    if (@available(iOS 11.0, *)) {
#else
    if (@available(macOS 10.13, *)) {
#endif
        options |= NSJSONWritingSortedKeys;
    } else {
        
    }
    
    NSData* json = [NSJSONSerialization dataWithJSONObject:jsonArray options:options error:&error];

    if (error) {
        NSLog(@"Error getting json for SFTP Connections: [%@]", error);
        return;
    }

    NSURL* fileUrl = [FileManager.sharedInstance.preferencesDirectory URLByAppendingPathComponent:kConfigFilename];

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
        NSLog(@"Error writing SFTP Connections file: [%@]-[%@]", error, writeError);
        return;
    }
    else {

    }
}

- (SFTPSessionConfiguration*)getById:(NSString*)identifier {
    NSMutableArray<SFTPSessionConfiguration*>* list = [self deserialize];

    return [list firstOrDefault:^BOOL(SFTPSessionConfiguration * _Nonnull obj) {
        return [obj.identifier isEqualToString:identifier];
    }];
}

- (void)addOrUpdate:(SFTPSessionConfiguration*)connection {
    NSMutableArray<SFTPSessionConfiguration*>* list = [self deserialize];

    NSInteger index = [list indexOfFirstMatch:^BOOL(SFTPSessionConfiguration * _Nonnull obj) {
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
    NSMutableArray<SFTPSessionConfiguration*>* list = [self deserialize];

    SFTPSessionConfiguration* connection = [list firstOrDefault:^BOOL(SFTPSessionConfiguration * _Nonnull obj) {
        return [obj.identifier isEqualToString:identifier];
    }];

    [list removeObject:connection];
    
    [connection clearKeychainItems];
    
    [self serialize:list];
}

- (NSArray<SFTPSessionConfiguration*>*)snapshot {
    NSMutableArray<SFTPSessionConfiguration*>* list = [self deserialize];

    return list.copy;
}

@end
