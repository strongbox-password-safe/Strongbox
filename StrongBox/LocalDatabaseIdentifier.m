//
//  LocalDatabaseIdentifier.m
//  Strongbox
//
//  Created by Mark on 17/06/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "LocalDatabaseIdentifier.h"

@implementation LocalDatabaseIdentifier

+ (instancetype)fromJson:(NSString *)json {
    //slog(@"Deserializing from [%@]", json);
    
    NSError* error;
    NSDictionary* dictionary = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                               options:kNilOptions
                                                                 error:&error];

    if(error) {
        slog(@"%@", error);
        return nil;
    }
    
    return [LocalDatabaseIdentifier fromSerializationDictionary:dictionary];
}

+ (instancetype)fromSerializationDictionary:(NSDictionary *)dictionary {
    LocalDatabaseIdentifier *pd = [[LocalDatabaseIdentifier alloc] init];
    
    NSNumber* num = (NSNumber*)dictionary[@"sharedStorage"];
    
    pd.sharedStorage = num.boolValue;
    pd.filename = dictionary[@"filename"];
    
    return pd;
}

- (NSString *)toJson {
    NSDictionary* dictionary = [self serializationDictionary];
    
    NSError* error;
    NSData* data = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:&error];
    
    if (error) {
        slog(@"%@", error);
        return nil;
    }
    
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    
    
    return json;
}

- (NSDictionary *)serializationDictionary {
    return @{ @"sharedStorage" : @(self.sharedStorage), @"filename" : self.filename };
}


@end
