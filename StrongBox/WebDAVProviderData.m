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
        
    [dict setObject:self.href forKey:@"href"];
    
    if ( self.connectionIdentifier ) {
        dict[@"connectionIdentifier"] = self.connectionIdentifier;
    }

    return dict;
}

+ (instancetype)fromSerializationDictionary:(NSDictionary *)dictionary {
    WebDAVProviderData *pd = [[WebDAVProviderData alloc] init];
    
    pd.href = [dictionary objectForKey:@"href"];
    
    if ( dictionary[@"connectionIdentifier"] ) {
        pd.connectionIdentifier = dictionary[@"connectionIdentifier"];
    }
    
    return pd;
}

-(NSString *)description {
    return [NSString stringWithFormat:@"href: [%@]", self.href];
}

@end
