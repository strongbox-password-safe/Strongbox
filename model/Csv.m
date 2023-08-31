//
//  Csv.m
//  Strongbox-iOS
//
//  Created by Mark on 09/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "Csv.h"
#import "CHCSVParser.h"
#import "OTPToken+Serialization.h"

@implementation Csv

+ (NSData*)getGroupAsCsv:(Node*)rootGroup {
    NSArray<Node*>* nodes = [rootGroup filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        return !node.isGroup;
    }];
    
    return [Csv getNodesAsCsv:nodes];
}

+ (NSData*)getNodesAsCsv:(NSArray<Node*>*)nodes {
    NSOutputStream *output = [NSOutputStream outputStreamToMemory];
    CHCSVWriter *writer = [[CHCSVWriter alloc] initWithOutputStream:output encoding:NSUTF8StringEncoding delimiter:','];
    
    [writer writeLineOfFields:@[kCSVHeaderTitle, kCSVHeaderUsername, kCSVHeaderEmail, kCSVHeaderPassword, kCSVHeaderUrl, kCSVHeaderTotp, kCSVHeaderNotes]];
    
    for(Node* node in nodes) {
        if ( node.isGroup) {
            continue;
        }
        
        NSString *otp = @"";
        
        if ( node.fields.otpToken != nil ) {
            otp = [node.fields.otpToken url:YES].absoluteString;
        }
        
        [writer writeLineOfFields:@[node.title, node.fields.username, node.fields.email, node.fields.password, node.fields.url, otp, node.fields.notes]];
    }
    
    [writer closeStream];
    
    NSData *contents = [output propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
    [output close];
    
    return contents;
}

@end
