//
//  BrowseTableViewCellHelper.m
//  Strongbox
//
//  Created by Mark on 24/04/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "BrowseTableViewCellHelper.h"
#import "NodeIconHelper.h"
#import "BrowseItemCell.h"
#import "BrowseItemTotpCell.h"
#import "NSDate+Extensions.h"
#import "Utils.h"
#import "Constants.h"

static NSString* const kBrowseItemCell = @"BrowseItemCell";
static NSString* const kBrowseItemTotpCell = @"BrowseItemTotpCell";
static NSString* const kBrowseQuickViewItemCell = @"BrowseQuickViewItemCell";

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
        [self.tableView registerNib:[UINib nibWithNibName:kBrowseQuickViewItemCell bundle:nil] forCellReuseIdentifier:kBrowseQuickViewItemCell];
    }
    return self;
}

- (UITableViewCell*)getTagCell:(NSIndexPath*)indexPath tag:(NSString*)tag {
    UITableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kBrowseQuickViewItemCell forIndexPath:indexPath];
    
    cell.textLabel.text = tag;
    
    NSArray<Node*>* items = [self.viewModel entriesWithTag:tag];
    
    if ( items.count == 1 ) {
        cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"generic_single_item_singular_fmt", @"%@ Item"), @(items.count).stringValue];
    }
    else {
        cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"generic_number_of_items_plural_fmt", @"%@ Items"), @(items.count).stringValue];
    }
    
    cell.imageView.image = [UIImage systemImageNamed:@"tag.fill"];
    cell.imageView.tintColor = nil;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
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
                        showLargeTotpCell:(BOOL)showLargeTotpCell
                        showGroupLocation:(BOOL)showGroupLocation
                    groupLocationOverride:(NSString*)groupLocationOverride
                            accessoryType:(UITableViewCellAccessoryType)accessoryType
                                  noFlags:(BOOL)noFlags {
    return [self getBrowseCellForNode:node indexPath:indexPath showLargeTotpCell:showLargeTotpCell showGroupLocation:showGroupLocation groupLocationOverride:groupLocationOverride accessoryType:accessoryType noFlags:NO showGroupChildCount:YES];
}

- (UITableViewCell *)getBrowseCellForNode:(Node *)node
                                indexPath:(NSIndexPath *)indexPath
                        showLargeTotpCell:(BOOL)showLargeTotpCell
                        showGroupLocation:(BOOL)showGroupLocation
                    groupLocationOverride:(NSString *)groupLocationOverride
                            accessoryType:(UITableViewCellAccessoryType)accessoryType
                                  noFlags:(BOOL)noFlags
                      showGroupChildCount:(BOOL)showGroupChildCount {
    return [self getBrowseCellForNode:node indexPath:indexPath showLargeTotpCell:showLargeTotpCell showGroupLocation:showGroupLocation groupLocationOverride:groupLocationOverride accessoryType:accessoryType noFlags:NO showGroupChildCount:showGroupChildCount subtitleOverride:nil];
}

- (UITableViewCell *)getBrowseCellForNode:(Node *)node
                                indexPath:(NSIndexPath *)indexPath
                        showLargeTotpCell:(BOOL)showLargeTotpCell
                        showGroupLocation:(BOOL)showGroupLocation
                    groupLocationOverride:(NSString *)groupLocationOverride
                            accessoryType:(UITableViewCellAccessoryType)accessoryType
                                  noFlags:(BOOL)noFlags
                      showGroupChildCount:(BOOL)showGroupChildCount
                         subtitleOverride:(NSNumber *)subtitleOverride {
    if (!node) { 
        BrowseItemCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kBrowseItemCell forIndexPath:indexPath];
        return cell;
    }
        
    NSString* title = self.viewModel.metadata.viewDereferencedFields ? [self dereference:node.title node:node] : node.title;
    UIImage* icon = [NodeIconHelper getIconForNode:node predefinedIconSet:self.viewModel.metadata.keePassIconSet format:self.viewModel.database.originalFormat];



    if(showLargeTotpCell) {
        BrowseItemTotpCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kBrowseItemTotpCell forIndexPath:indexPath];
        NSString* subtitle = [self getBrowseItemSubtitle:node subtitleOverride:subtitleOverride];

        [cell setItem:title subtitle:subtitle icon:icon expired:node.expired otpToken:node.fields.otpToken hideIcon:self.viewModel.metadata.hideIconInBrowse];
        
        return cell;
    }
    else {
        BrowseItemCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kBrowseItemCell forIndexPath:indexPath];

        NSString *groupLocation = showGroupLocation ? (groupLocationOverride ? groupLocationOverride : [self getGroupPathDisplayString:node]) : @"";
        
        NSDictionary<NSNumber*, UIColor*> *flagTintColors = @{};
        
        NSString* briefAudit = !noFlags ? [self.viewModel getQuickAuditVeryBriefSummaryForNode:node.uuid] : @"";
        NSArray* flags = !noFlags ? [self getFlags:node isFlaggedByAudit:briefAudit.length tintColors:&flagTintColors] : @[];
        
        if(node.isGroup) {
            BOOL isRecycleBin = (self.viewModel.database.recycleBinEnabled && node == self.viewModel.database.recycleBinNode);

            NSString* childCount = self.viewModel.metadata.showChildCountOnFolderInBrowse && showGroupChildCount ? [NSString stringWithFormat:@"(%lu)", (unsigned long)node.children.count] : @"";
                            
            [cell setGroup:title
                      icon:icon
                childCount:childCount
                    italic:isRecycleBin
             groupLocation:groupLocation
                 tintColor:isRecycleBin ? Constants.recycleBinTintColor : nil
                     flags:flags
            flagTintColors:flagTintColors
                  hideIcon:self.viewModel.metadata.hideIconInBrowse
                 textColor:isRecycleBin ? Constants.recycleBinTintColor : nil];
        }
        else {
            NSString* subtitle = [self getBrowseItemSubtitle:node subtitleOverride:subtitleOverride];
            
            [cell setRecord:title
                   subtitle:subtitle
                       icon:icon
              groupLocation:groupLocation
                      flags:flags
             flagTintColors:flagTintColors
                    expired:node.expired
                   otpToken:node.fields.otpToken
                   hideIcon:self.viewModel.metadata.hideIconInBrowse
                      audit:briefAudit];
            
            cell.accessoryType = accessoryType;
        }
        
        return cell;
    }
}

- (NSArray<UIImage*>*)getFlags:(Node*)node isFlaggedByAudit:(BOOL)isFlaggedByAudit tintColors:(NSDictionary<NSNumber*, UIColor*>**)tintColors {
    NSMutableArray<UIImage*> *flags = NSMutableArray.array;
    NSMutableDictionary<NSNumber*, UIColor*> *tintsMap = NSMutableDictionary.dictionary;
    
    if([self.viewModel isFavourite:node.uuid]) {
        UIImage* image = [UIImage systemImageNamed:@"star.fill"];

        tintsMap[@(flags.count)] = UIColor.systemYellowColor;
        [flags addObject:image];
    }

    if(!node.isGroup && node.fields.attachments.count) {
        UIImage* image = [UIImage systemImageNamed:@"paperclip"];
        [flags addObject:image];
    }
    
    if(!node.isGroup && isFlaggedByAudit) {
        UIImage* auditImage = [UIImage systemImageNamed:@"checkmark.shield"];
        
        if(tintColors) {
            tintsMap[@(flags.count)] = UIColor.systemOrangeColor;
        }

        [flags addObject:auditImage];
    }

    if(tintColors) {
        *tintColors = tintsMap;
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

- (NSString*)getBrowseItemSubtitle:(Node*)node {
    return [self getBrowseItemSubtitle:node subtitleOverride:nil];
}

- (NSString*)getBrowseItemSubtitle:(Node*)node subtitleOverride:(NSNumber*_Nullable)subtitleOverride {
    BrowseItemSubtitleField field = subtitleOverride != nil ? subtitleOverride.intValue : self.viewModel.metadata.browseItemSubtitleField;
    
    switch (field) {
        case kBrowseItemSubtitleNoField:
            return @"";
            break;
        case kBrowseItemSubtitleUsername:
            return self.viewModel.metadata.viewDereferencedFields ? [self dereference:node.fields.username node:node] : node.fields.username;
            break;
        case kBrowseItemSubtitlePassword:
            return self.viewModel.metadata.viewDereferencedFields ? [self dereference:node.fields.password node:node] : node.fields.password;
            break;
        case kBrowseItemSubtitleUrl:
            return self.viewModel.metadata.viewDereferencedFields ? [self dereference:node.fields.url node:node] : node.fields.url;
            break;
        case kBrowseItemSubtitleEmail:
            return self.viewModel.metadata.viewDereferencedFields ? [self dereference:node.fields.email node:node] : node.fields.email;
            break;
        case kBrowseItemSubtitleModified:
            return node.fields.modified ? node.fields.modified.friendlyDateTimeString : @"";
            break;
        case kBrowseItemSubtitleCreated:
            return node.fields.created ? node.fields.created.friendlyDateTimeString : @"";
            break;
        case kBrowseItemSubtitleNotes:
            return self.viewModel.metadata.viewDereferencedFields ? [self dereference:node.fields.notes node:node] : node.fields.notes;
            break;
        case kBrowseItemSubtitleTags:
            return sortedTagsString(node);
            break;
        default:
            return @"";
            break;
    }
}

NSString* sortedTagsString(Node* node) {
    NSArray<NSString*> *sortedTags = [node.fields.tags.allObjects sortedArrayUsingComparator:finderStringComparator];
    return [sortedTags componentsJoinedByString:@", "];
}

@end
