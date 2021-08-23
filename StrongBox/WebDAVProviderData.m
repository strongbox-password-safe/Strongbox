//
//  WebDAVProviderData.m
//  Strongbox
//
//  Created by Mark on 11/12/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "WebDAVProviderData.h"

@interface WebDAVProviderData ()

@end

@implementation WebDAVProviderData

- (NSDictionary *)serializationDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    if ( self.sessionConfiguration ) {
        [dict addEntriesFromDictionary:[self.sessionConfiguration serializationDictionary]];
    }
    
    [dict setObject:self.href forKey:@"href"];
    
    if ( self.connectionIdentifier ) {
        dict[@"connectionIdentifier"] = self.connectionIdentifier;
    }
    else {
        dict[@"connectionIdentifier"] = self.sessionConfiguration.identifier;
    }

    return dict;
}

+ (instancetype)fromSerializationDictionary:(NSDictionary *)dictionary {
    WebDAVProviderData *pd = [[WebDAVProviderData alloc] init];
    
    pd.href = [dictionary objectForKey:@"href"];
    
    WebDAVSessionConfiguration* config = [WebDAVSessionConfiguration fromSerializationDictionary:dictionary];
    
    if ( config ) {
        pd.sessionConfiguration = config;
    }
    
    if ( dictionary[@"connectionIdentifier"] ) {
        pd.connectionIdentifier = dictionary[@"connectionIdentifier"];
    }
    else if ( config ) { 
        pd.connectionIdentifier = config.identifier;
    }
    
    return pd;
}

-(NSString *)description {
    return [NSString stringWithFormat:@"href: [%@]", self.href];
}

@end
