//
//  QuickTypeRecordIdentifier.m
//  Strongbox
//
//  Created by Mark on 31/03/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "QuickTypeRecordIdentifier.h"
#import "SBLog.h"

static NSString* const kDatabaseIdKey = @"safeId";
static NSString* const kNodeIdKey = @"nodeId";
static NSString* const kFieldKeyKey = @"fieldKey";

@implementation QuickTypeRecordIdentifier

+ (instancetype)identifierWithDatabaseId:(NSString *)databaseId nodeId:(NSString *)nodeId fieldKey:(NSString * _Nullable)fieldKey {
    QuickTypeRecordIdentifier* ret = [[QuickTypeRecordIdentifier alloc] init];
    
    ret.databaseId = databaseId;
    ret.nodeId = nodeId;
    ret.fieldKey = fieldKey;
    
    return ret;
}

+ (instancetype)fromJson:(NSString *)json {
    if ( !json ) {
        return nil;
    }
    
    NSError* error;
    NSDictionary* dictionary = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:&error];
    
    if(dictionary) {
        return [QuickTypeRecordIdentifier identifierWithDatabaseId:dictionary[kDatabaseIdKey] nodeId:dictionary[kNodeIdKey] fieldKey:dictionary[kFieldKeyKey]];
    }
    else {
        slog(@"Could not deserialize from: %@",error);
        return nil;
    }
}

- (NSString *)toJson {
    NSError* error;
    NSDictionary *dict = self.fieldKey ? @{
        kDatabaseIdKey : self.databaseId,
        kNodeIdKey : self.nodeId,
        kFieldKeyKey : self.fieldKey
    } : @{
        kDatabaseIdKey : self.databaseId,
        kNodeIdKey : self.nodeId,
    };
    
    NSData* data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
    
    if(data) {
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    else {
        slog(@"Error Serializing: %@", error);
        return nil;
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"database = {%@}, node = {%@}", self.databaseId, self.nodeId];
}

@end
