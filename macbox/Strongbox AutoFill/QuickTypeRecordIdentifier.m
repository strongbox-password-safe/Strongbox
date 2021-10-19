//
//  QuickTypeRecordIdentifier.m
//  Strongbox
//
//  Created by Mark on 31/03/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "QuickTypeRecordIdentifier.h"

static NSString* const kDatabaseIdKey = @"safeId";
static NSString* const kNodeIdKey = @"nodeId";

@implementation QuickTypeRecordIdentifier

+ (instancetype)identifierWithDatabaseId:(NSString *)databaseId nodeId:(NSString *)nodeId {
    QuickTypeRecordIdentifier* ret = [[QuickTypeRecordIdentifier alloc] init];
    
    ret.databaseId = databaseId;
    ret.nodeId = nodeId;
    
    return ret;
}

+ (instancetype)fromJson:(NSString *)json {
    NSError* error;
    NSDictionary* dictionary = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:&error];
    
    if(dictionary) {
        return [QuickTypeRecordIdentifier identifierWithDatabaseId:dictionary[kDatabaseIdKey] nodeId:dictionary[kNodeIdKey]];
    }
    else {
        NSLog(@"Could not deserialize from: %@",error);
        return nil;
    }
}

- (NSString *)toJson {
    NSError* error;
    NSDictionary *dict = @{ kDatabaseIdKey : self.databaseId, kNodeIdKey : self.nodeId };
    NSData* data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
    
    if(data) {
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    else {
        NSLog(@"Error Serializing: %@", error);
        return nil;
    }
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"database = {%@}, node = {%@}", self.databaseId, self.nodeId];
}

@end
