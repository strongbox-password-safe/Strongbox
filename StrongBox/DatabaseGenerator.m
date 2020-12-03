//
//  DatabaseGenerator.m
//  Strongbox-iOS
//
//  Created by Mark on 17/04/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "DatabaseGenerator.h"
#import "PasswordMaker.h"

@implementation DatabaseGenerator

+ (DatabaseModel*)generateEmpty:(NSString*)password {
    DatabaseModel* db = [[DatabaseModel alloc] initEmptyForTesting:[CompositeKeyFactors password:password]];

    return db;
}

+ (DatabaseModel*)generate:(NSString*)password {
    DatabaseModel* db = [[DatabaseModel alloc] initEmptyForTesting:[CompositeKeyFactors password:password]];
    
    int groupCount = 10;
    int subGroupCount = 2;
    int entryCount = 10;
    
    for(int i=0;i<groupCount;i++) {
        for(int k=0;k<subGroupCount;k++) {
            NSString* title;
            Node* existing;
            do {
                title = [PasswordMaker.sharedInstance generateRandomWord];
                existing = [db.rootGroup findFirstChild:NO predicate:^BOOL(Node * _Nonnull node) {
                    return [node.title isEqualToString:title];
                }];
            } while (existing);
            
            Node* childGroup = [[Node alloc] initAsGroup:title parent:db.rootGroup keePassGroupTitleRules:NO uuid:nil];
            
            [db.rootGroup addChild:childGroup keePassGroupTitleRules:NO];
            
            for (int j = 0; j < entryCount; j++) {
                Node* childEntry = [self createSampleEntry:j parentGroup:childGroup];
                [childGroup addChild:childEntry keePassGroupTitleRules:YES];
            }
        }
    }
    
    return db;
}

+ (Node *)generateSampleNode:(Node *)parentGroup {
    return [DatabaseGenerator createSampleEntry:arc4random_uniform(100) parentGroup:parentGroup];
}

+ (Node*)createSampleEntry:(int)index parentGroup:(Node*)parentGroup {
    NSString* title = [PasswordMaker.sharedInstance generateRandomWord];
    NSString* username = [PasswordMaker.sharedInstance generateUsername];
    NSString* password = [PasswordMaker.sharedInstance generateWithDefaultConfig];
    NSString* email = [PasswordMaker.sharedInstance generateEmail];

    NSString* url = [NSString stringWithFormat:@"https:
    NSString* notes = [NSString stringWithFormat:@"notes could be quite long too-%d", index];

    NodeFields *fields = [[NodeFields alloc] initWithUsername:username
                                                          url:url
                                                     password:password
                                                        notes:notes
                                                        email:email];
    
    Node* childEntry = [[Node alloc] initAsRecord:title parent:parentGroup fields:fields uuid:nil];
    
    
    
    return childEntry;
}

@end
