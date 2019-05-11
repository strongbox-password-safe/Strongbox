//
//  SFTPProviderData.m
//  Strongbox
//
//  Created by Mark on 11/12/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "SFTPProviderData.h"

@implementation SFTPProviderData

-(NSDictionary *)serializationDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[self.sFtpConfiguration serializationDictionary]];
    [dict setObject:self.filePath forKey:@"filePath"];
    
    return dict;
}

+ (instancetype)fromSerializationDictionary:(NSDictionary *)dictionary {
    SFTPProviderData *pd = [[SFTPProviderData alloc] init];
    
    pd.filePath = [dictionary objectForKey:@"filePath"];
    pd.sFtpConfiguration = [SFTPSessionConfiguration fromSerializationDictionary:dictionary];
    
    return pd;
}

@end
