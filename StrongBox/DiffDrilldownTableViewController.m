//
//  DiffDrilldownTableViewController.m
//  Strongbox
//
//  Created by Strongbox on 15/12/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "DiffDrilldownTableViewController.h"
#import "NSDate+Extensions.h"
#import "MutableOrderedDictionary.h"
#import "UiAttachment.h"

@interface DiffDrilldownTableViewController ()

@property MutableOrderedDictionary<NSString*, NSString*> *diffs;

@end

@implementation DiffDrilldownTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.tableFooterView = UIView.new;
    
    [self initializeDiffs];
}

- (void)initializeDiffs {
    self.diffs = [[MutableOrderedDictionary alloc] init];
    
    Node* mine = self.diffPair.a;
    Node* other = self.diffPair.b;
    
    if (! [mine.uuid isEqual:other.uuid] ) {
        self.diffs[@"WARNWARN: Diff Pair have different UUIDs - Something very wrong - Please contact support@strongboxsafe.com"] = @"";;
        return;
    }
    
    
    
    if ( [mine.title compare:other.title] != NSOrderedSame ) {
        self.diffs[@"Titles are Different."] = [NSString stringWithFormat:@"[%@] < [%@]", mine.title, other.title]; 
    }

    

    if (mine.isGroup) {
        
        BOOL ret = [other.fields.modified isLaterThan:mine.fields.modified]; 

        if (ret) {
            NSLog(@"%@ = %@ ? %d", mine.fields.modified, other.fields.modified, ret);
            self.diffs[@"Modified Dates are different."] = [NSString stringWithFormat:@"[%@] < [%@]", mine.fields.modified.friendlyDateString, other.fields.modified.friendlyDateString]; 
        }
        
        return;
    }
    
    
        
    if (!( ( mine.iconId == nil && other.iconId == nil ) || (mine.iconId && other.iconId && ([mine.iconId isEqual:other.iconId])))) {
        self.diffs[@"Icons are different."] = @""; 
    }

    if( ! ( (mine.customIconUuid == nil && other.customIconUuid == nil) || (mine.customIconUuid && other.customIconUuid && [mine.customIconUuid isEqual:other.customIconUuid]))) {
        self.diffs[@"Custom Icons are different."] = [NSString stringWithFormat:@"[%@] < [%@]", mine.customIconUuid, other.customIconUuid]; 
    }
    
    
    
    if ( [mine.fields.username compare:other.fields.username] != NSOrderedSame ) { self.diffs[@"Username are different."] = [NSString stringWithFormat:@"[%@] < [%@]", mine.fields.username, other.fields.username]; } 
    if ( [mine.fields.password compare:other.fields.password] != NSOrderedSame ) { self.diffs[@"Password are different."] = [NSString stringWithFormat:@"[%@] < [%@]", mine.fields.password, other.fields.password]; } 
    if ( [mine.fields.url compare:other.fields.url] != NSOrderedSame ) { self.diffs[@"URLs are different."] = [NSString stringWithFormat:@"[%@] < [%@]", mine.fields.url, other.fields.url]; } 
    if ( [mine.fields.notes compare:other.fields.notes] != NSOrderedSame ) { self.diffs[@"Notes are different."] = [NSString stringWithFormat:@"[%@] < [%@]", mine.fields.notes, other.fields.notes]; } 
    if ( [mine.fields.email compare:other.fields.email] != NSOrderedSame ) { self.diffs[@"Email are different."] = [NSString stringWithFormat:@"[%@] < [%@]", mine.fields.email, other.fields.email]; } 

    
    
    if ( mine.fields.customFields.count != other.fields.customFields.count) {
        self.diffs[@"Custom Field counts are different."] = [NSString stringWithFormat:@"[%lu] < [%lu]", (unsigned long)mine.fields.customFields.count, (unsigned long)other.fields.customFields.count];  
    }

    for (NSString* key in mine.fields.customFields.allKeys) {
        StringValue* a = mine.fields.customFields[key];
        StringValue* b = other.fields.customFields[key];
        
        if(![a isEqual:b]) {
            self.diffs[@"Custom Field is different."] = [NSString stringWithFormat:@"[%@] < [%@]", a, b];  
        }
    }

    
    
    if(mine.fields.attachments.count != other.fields.attachments.count) {
        self.diffs[@"Attachment counts are different."] = [NSString stringWithFormat:@"[%lu] < [%lu]", (unsigned long)mine.fields.customFields.count, (unsigned long)other.fields.customFields.count];  
    }

    
    
    for (int i=0; i < mine.fields.attachments.count; i++) {
        NodeFileAttachment* a = mine.fields.attachments[i];
        
        if (i < other.fields.attachments.count) {
            NodeFileAttachment* b = other.fields.attachments[i];
            
            UiAttachment* alpha = [self.firstDatabase.database getUiAttachment:a];
            UiAttachment* beta = [self.secondDatabase.database getUiAttachment:b];
            
            if ( [alpha.filename compare:beta.filename] != NSOrderedSame ) {
                self.diffs[@"Attachment Filename is different."] = [NSString stringWithFormat:@"[%@] < [%@]", alpha.filename, beta.filename];  
            }
            else {
                if (![alpha.dbAttachment.digestHash isEqualToString:beta.dbAttachment.digestHash]) {
                    self.diffs[[NSString stringWithFormat:@"Attachment [%@] Content is different.", alpha.filename]] = [NSString stringWithFormat:@"[%@] < [%@]", alpha.dbAttachment.digestHash, beta.dbAttachment.digestHash];  
                }
            }
        }
    }

    
    
    if ((mine.fields.created == nil && other.fields.created != nil) || (mine.fields.created != nil && ![mine.fields.created isEqualToDate:other.fields.created] ))     {
        self.diffs[@"Created Dates are different."] = [NSString stringWithFormat:@"[%@] < [%@]", mine.fields.created.friendlyDateString, other.fields.created.friendlyDateString];
    } 

    if ((mine.fields.modified == nil && other.fields.modified != nil) || (mine.fields.modified != nil && ![mine.fields.modified isEqualToDate:other.fields.modified] ))     {
        self.diffs[@"Modified Dates are different."] = [NSString stringWithFormat:@"[%@] < [%@]", mine.fields.modified.friendlyDateString, other.fields.modified.friendlyDateString];
    } 

    if ((mine.fields.expires == nil && other.fields.expires != nil) || (mine.fields.expires != nil && ![mine.fields.expires isEqualToDate:other.fields.expires] )) {
        self.diffs[@"Expiry Dates are different."] = [NSString stringWithFormat:@"[%@] < [%@]", mine.fields.expires.friendlyDateString, other.fields.expires.friendlyDateString];
    } 
        
    if ((mine.fields.foregroundColor == nil && other.fields.foregroundColor != nil) || (mine.fields.foregroundColor != nil && ![mine.fields.foregroundColor isEqual:other.fields.foregroundColor] )) {
        self.diffs[@"ForegroundColor are different."] = [NSString stringWithFormat:@"[%@] < [%@]", mine.fields.foregroundColor, other.fields.foregroundColor]; 
    }
    
    if ((mine.fields.backgroundColor == nil && other.fields.backgroundColor != nil) || (mine.fields.backgroundColor != nil && ![mine.fields.backgroundColor isEqual:other.fields.backgroundColor] )) {
        self.diffs[@"BackgroundColor are different."] = [NSString stringWithFormat:@"[%@] < [%@]", mine.fields.backgroundColor, other.fields.backgroundColor]; 
    }
    
    if ((mine.fields.overrideURL == nil && other.fields.overrideURL != nil) || (mine.fields.overrideURL != nil && ![mine.fields.overrideURL isEqual:other.fields.overrideURL] )) {
        self.diffs[@"OverrideURL are different."] = [NSString stringWithFormat:@"[%@] < [%@]", mine.fields.overrideURL, other.fields.overrideURL]; 
    }
    
    if ((mine.fields.autoType == nil && other.fields.autoType != nil) || (mine.fields.autoType != nil && ![mine.fields.autoType isEqual:other.fields.autoType])) {
        self.diffs[@"AutoType are different."] = [NSString stringWithFormat:@"[%@] < [%@]", mine.fields.autoType, other.fields.autoType]; 
    }
    
    if ( ![mine.fields.tags isEqualToSet:other.fields.tags] ) { self.diffs[@"Tags are different."] = [NSString stringWithFormat:@"[%@] < [%@]", mine.fields.tags, other.fields.tags]; } 

    if ( ![mine.fields.customData isEqual:other.fields.customData] ) { self.diffs[@"CustomData are different."] = [NSString stringWithFormat:@"[%@] < [%@]", mine.fields.customData, other.fields.customData]; } 
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.diffs.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString* title = self.diffs.allKeys[indexPath.row];
    NSString* subtitle = self.diffs[title];
    
    UITableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:@"diffDrillDownCellIdentifer" forIndexPath:indexPath];
    
    cell.textLabel.text = title;
    cell.detailTextLabel.text = subtitle;
    
    return cell;
}

@end
