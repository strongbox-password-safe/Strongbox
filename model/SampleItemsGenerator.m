//
//  SampleItemsGenerator.m
//  Strongbox
//
//  Created by Strongbox on 20/12/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "SampleItemsGenerator.h"
#import "PasswordMaker.h"

@implementation SampleItemsGenerator

+ (void)addSampleGroupAndRecordToRoot:(DatabaseModel*)database passwordConfig:(PasswordGenerationConfig*)passwordConfig {
    if ( !database.effectiveRootGroup ) {
        return;
    }

    Node* root;
    
    if(database.originalFormat != kKeePass1) {
        root = database.effectiveRootGroup;
    }
    else if (database.effectiveRootGroup.childGroups.count > 0) {
        root = database.effectiveRootGroup.childGroups[0];
    }
    else {
        return;
    }
    
    [SampleItemsGenerator addSampleGroupAndRecordToGroup:database parent:root passwordConfig:passwordConfig];
}

+ (void)addSampleGroupAndRecordToGroup:(DatabaseModel*)database parent:(Node*)parent passwordConfig:(PasswordGenerationConfig*)passwordConfig {
    NSString* password = [PasswordMaker.sharedInstance generateForConfigOrDefault:passwordConfig];

    Node* sampleFolder = [[Node alloc] initAsGroup:NSLocalizedString(@"model_sample_group_title", @"Sample Group")
                                            parent:parent
                            keePassGroupTitleRules:NO
                                              uuid:nil];

    [database addChildren:@[sampleFolder] destination:parent];

    NodeFields *fields = [[NodeFields alloc] initWithUsername:NSLocalizedString(@"model_sample_entry_username", @"username")
                                                          url:@"https:
                                                     password:password
                                                        notes:@""
                                                        email:@""];
    
    Node* sampleEntry = [[Node alloc] initAsRecord:NSLocalizedString(@"model_sample_entry_title", @"Sample")
                                         parent:parent
                                         fields:fields
                                           uuid:nil];
    
    [database addChildren:@[sampleEntry] destination:parent]; 
}

@end
