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

    NSDictionary* config = [self.sFtpConfiguration serializationDictionary];
    
    if ( config ) {
        [dict addEntriesFromDictionary:config];
    }
    
    [dict setObject:self.filePath forKey:@"filePath"];
    
    if ( self.connectionIdentifier ) {
        dict[@"connectionIdentifier"] = self.connectionIdentifier;
    }
    else if ( config ){
        dict[@"connectionIdentifier"] = self.sFtpConfiguration.identifier;
    }
    
    return dict;
}

+ (instancetype)fromSerializationDictionary:(NSDictionary *)dictionary {
    SFTPProviderData *pd = [[SFTPProviderData alloc] init];
    
    pd.filePath = [dictionary objectForKey:@"filePath"];
    
    SFTPSessionConfiguration* config = [SFTPSessionConfiguration fromSerializationDictionary:dictionary];
    
    if ( config ) {
        pd.sFtpConfiguration = config;
    }
    
    if ( dictionary[@"connectionIdentifier"] ) {
        pd.connectionIdentifier = dictionary[@"connectionIdentifier"];
    }
    else if ( config ) {
        pd.connectionIdentifier = config.identifier;
    }
    
    return pd;
}

@end
