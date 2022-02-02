//
//  SFTPProviderData.m
//  Strongbox
//
//  Created by Mark on 11/12/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "SFTPProviderData.h"

@interface SFTPProviderData ()

@end

@implementation SFTPProviderData

- (NSDictionary *)serializationDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    [dict setObject:self.filePath forKey:@"filePath"];
    
    if ( self.connectionIdentifier ) {
        dict[@"connectionIdentifier"] = self.connectionIdentifier;
    }
    
    return dict;
}

+ (instancetype)fromSerializationDictionary:(NSDictionary *)dictionary {
    SFTPProviderData *pd = [[SFTPProviderData alloc] init];
    
    pd.filePath = [dictionary objectForKey:@"filePath"];
        
    if ( dictionary[@"connectionIdentifier"] ) {
        pd.connectionIdentifier = dictionary[@"connectionIdentifier"];
    }
    
    return pd;
}

@end
