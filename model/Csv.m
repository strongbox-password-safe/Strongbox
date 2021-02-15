//
//  Csv.m
//  Strongbox-iOS
//
//  Created by Mark on 09/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "Csv.h"
#import "CHCSVParser.h"

@implementation Csv

+ (NSData*)getSafeAsCsv:(DatabaseModel*)database {
    NSArray<Node*>* nodes = [database.effectiveRootGroup filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        return !node.isGroup;
    }];
    
    NSOutputStream *output = [NSOutputStream outputStreamToMemory];
    CHCSVWriter *writer = [[CHCSVWriter alloc] initWithOutputStream:output encoding:NSUTF8StringEncoding delimiter:','];
    
    [writer writeLineOfFields:@[kCSVHeaderTitle, kCSVHeaderUsername, kCSVHeaderEmail, kCSVHeaderPassword, kCSVHeaderUrl, kCSVHeaderNotes]];
    
    for(Node* node in nodes) {
        [writer writeLineOfFields:@[node.title, node.fields.username, node.fields.email, node.fields.password, node.fields.url, node.fields.notes]];
    }
    
    [writer closeStream];
    
    NSData *contents = [output propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
    [output close];
    
    return contents;
}

@end
