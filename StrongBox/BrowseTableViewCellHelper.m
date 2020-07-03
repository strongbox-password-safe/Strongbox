//
//  BrowseTableViewCellHelper.m
//  Strongbox
//
//  Created by Mark on 24/04/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "BrowseTableViewCellHelper.h"
#import "NodeIconHelper.h"
#import "DatabaseSearchAndSorter.h"
#import "BrowseItemCell.h"
#import "BrowseItemTotpCell.h"

static NSString* const kBrowseItemCell = @"BrowseItemCell";
static NSString* const kBrowseItemTotpCell = @"BrowseItemTotpCell";

@interface BrowseTableViewCellHelper ()

@property Model* viewModel;
@property UITableView* tableView;

@end

@implementation BrowseTableViewCellHelper

- (instancetype)initWithModel:(Model*)model tableView:(UITableView*)tableView {
    self = [super init];
    if (self) {
        self.viewModel = model;
        self.tableView = tableView;
        
        [self.tableView registerNib:[UINib nibWithNibName:kBrowseItemCell bundle:nil] forCellReuseIdentifier:kBrowseItemCell];
        [self.tableView registerNib:[UINib nibWithNibName:kBrowseItemTotpCell bundle:nil] forCellReuseIdentifier:kBrowseItemTotpCell];
    }
    return self;
}

- (UITableViewCell *)getBrowseCellForNode:(Node*)node
                                indexPath:(NSIndexPath*)indexPath
                        showLargeTotpCell:(BOOL)showLargeTotpCell
                        showGroupLocation:(BOOL)showGroupLocation {
    return [self getBrowseCellForNode:node indexPath:indexPath showLargeTotpCell:showLargeTotpCell showGroupLocation:showGroupLocation groupLocationOverride:nil accessoryType:UITableViewCellAccessoryNone];
}

- (UITableViewCell *)getBrowseCellForNode:(Node*)node
            indexPath:(NSIndexPath*)indexPath
    showLargeTotpCell:(BOOL)showLargeTotpCell
    showGroupLocation:(BOOL)showGroupLocation
groupLocationOverride:(NSString*)groupLocationOverride
        accessoryType:(UITableViewCellAccessoryType)accessoryType {
    return [self getBrowseCellForNode:node indexPath:indexPath showLargeTotpCell:showLargeTotpCell showGroupLocation:showGroupLocation groupLocationOverride:groupLocationOverride accessoryType:accessoryType noFlags:NO];
}

- (UITableViewCell *)getBrowseCellForNode:(Node*)node
                                indexPath:(NSIndexPath*)indexPath
                        showLargeTotpCell:(BOOL)totp
                        showGroupLocation:(BOOL)showGroupLocation
                    groupLocationOverride:(NSString*)groupLocationOverride
                            accessoryType:(UITableViewCellAccessoryType)accessoryType
                                  noFlags:(BOOL)noFlags {
    NSString* title = self.viewModel.metadata.viewDereferencedFields ? [self dereference:node.title node:node] : node.title;
    UIImage* icon = [NodeIconHelper getIconForNode:node model:self.viewModel];

    DatabaseSearchAndSorter* searcher = [[DatabaseSearchAndSorter alloc] initWithModel:self.viewModel];

    if(totp) {
        BrowseItemTotpCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kBrowseItemTotpCell forIndexPath:indexPath];
        NSString* subtitle = [searcher getBrowseItemSubtitle:node];
        
        [cell setItem:title subtitle:subtitle icon:icon expired:node.expired otpToken:node.fields.otpToken];
        
        return cell;
    }
    else {
        BrowseItemCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kBrowseItemCell forIndexPath:indexPath];

        NSString *groupLocation = showGroupLocation ? (groupLocationOverride ? groupLocationOverride : [self getGroupPathDisplayString:node]) : @"";
        
        NSDictionary<NSNumber*, UIColor*> *flagTintColors = @{};
        
        NSString* briefAudit = self.viewModel.metadata.showFlagsInBrowse && !noFlags ? [self.viewModel getQuickAuditVeryBriefSummaryForNode:node] : @"";
        NSArray* flags = self.viewModel.metadata.showFlagsInBrowse && !noFlags ? [self getFlags:node isFlaggedByAudit:briefAudit.length tintColors:&flagTintColors] : @[];
        
        if(node.isGroup) {
            BOOL italic = (self.viewModel.database.recycleBinEnabled && node == self.viewModel.database.recycleBinNode);

            NSString* childCount = self.viewModel.metadata.showChildCountOnFolderInBrowse ? [NSString stringWithFormat:@"(%lu)", (unsigned long)node.children.count] : @"";
            
            [cell setGroup:title
                      icon:icon
                childCount:childCount
                    italic:italic
             groupLocation:groupLocation
                 tintColor:nil
                     flags:flags
                  hideIcon:self.viewModel.metadata.hideIconInBrowse];
        }
        else {
            NSString* subtitle = [searcher getBrowseItemSubtitle:node];
            
            [cell setRecord:title
                   subtitle:subtitle
                       icon:icon
              groupLocation:groupLocation
                      flags:flags
             flagTintColors:flagTintColors
                    expired:node.expired
                   otpToken:self.viewModel.metadata.hideTotpInBrowse ? nil : node.fields.otpToken
                   hideIcon:self.viewModel.metadata.hideIconInBrowse
                      audit:briefAudit];
            
            cell.accessoryType = accessoryType;
        }
        
        return cell;
    }
}

- (NSArray<UIImage*>*)getFlags:(Node*)node isFlaggedByAudit:(BOOL)isFlaggedByAudit tintColors:(NSDictionary<NSNumber*, UIColor*>**)tintColors {
    if ( !self.viewModel.metadata.showFlagsInBrowse ) {
        if(*tintColors) {
            *tintColors = @{};
        }
        return @[];
    }

    NSMutableArray<UIImage*> *flags = NSMutableArray.array;
    
    if([self.viewModel isPinned:node]) {
        UIImage* image;
        if (@available(iOS 13.0, *)) {
           image = [UIImage systemImageNamed:@"pin"];
        }
        else {
           image = [UIImage imageNamed:@"pin"];
        }

        [flags addObject:image];
    }

    if(!node.isGroup && node.fields.attachments.count) {
        UIImage* image;
        if (@available(iOS 13.0, *)) {
            image = [UIImage systemImageNamed:@"paperclip"];
        }
        else {
            image = [UIImage imageNamed:@"attach"];
        }
        [flags addObject:image];
    }
    
    if(!node.isGroup && isFlaggedByAudit) {
        UIImage* image;
        UIColor* tintColor;
        image = [UIImage imageNamed:@"security_checked"];
        tintColor = UIColor.systemOrangeColor;
        
        if(tintColors) {
            *tintColors = @{ @(flags.count) : tintColor };
        }

        [flags addObject:image];
    }

    return flags;
}

- (NSString*)dereference:(NSString*)text node:(Node*)node {
    return [self.viewModel.database dereference:text node:node];
}

- (NSString *)getGroupPathDisplayString:(Node *)vm {
    return [NSString stringWithFormat:NSLocalizedString(@"browse_vc_group_path_string_fmt", @"(in %@)"),
            [self.viewModel.database getSearchParentGroupPathDisplayString:vm]];
}

@end
