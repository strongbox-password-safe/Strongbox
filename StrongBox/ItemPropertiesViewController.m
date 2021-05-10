//
//  GroupDetailsController.m
//  Strongbox
//
//  Created by Strongbox on 02/11/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "ItemPropertiesViewController.h"
#import "SwitchTableViewCell.h"
#import "MutableOrderedDictionary.h"
#import "GenericKeyValueTableViewCell.h"
#import "GenericBasicCell.h"
#import "Utils.h"
#import "NSDate+Extensions.h"
#import "ClipboardManager.h"
#import "NSUUID+Zero.h"
#import "TagsViewTableViewCell.h"

#ifndef IS_APP_EXTENSION
#import "ISMessages/ISMessages.h"
#endif

static NSString* const kSwitchTableCellId = @"SwitchTableCell";
static NSString* const kGenericKeyValueCellId = @"GenericKeyValueTableViewCell";
static NSString* const kGenericBasicCellId = @"GenericBasicCell";
static NSString* const kTagsViewCellId = @"TagsViewCell";

const static NSUInteger kSectionPropertiesIdx = 0;
const static NSUInteger kSectionTagsIdx = 1; 
const static NSUInteger kSectionNotesIdx = 2; 
const static NSUInteger kSectionDatesIdx = 3;
const static NSUInteger kSectionCustomDataIdx = 4;

const static NSUInteger kSectionCount = 5;
const static NSUInteger kSectionUuidIdx = 5; 

@interface ItemPropertiesViewController ()

@property MutableOrderedDictionary<NSString*, NSString*>* customData;
@property NSString* notes;
@property MutableOrderedDictionary* dates;

@property MutableOrderedDictionary<NSString*, NSString*>* properties;

@end

@implementation ItemPropertiesViewController

- (IBAction)onCancel:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.navigationItem setTitle:self.item.title];
    
    [self.tableView registerNib:[UINib nibWithNibName:kSwitchTableCellId bundle:nil] forCellReuseIdentifier:kSwitchTableCellId];
    [self.tableView registerNib:[UINib nibWithNibName:kGenericKeyValueCellId bundle:nil] forCellReuseIdentifier:kGenericKeyValueCellId];
    [self.tableView registerNib:[UINib nibWithNibName:kGenericBasicCellId bundle:nil] forCellReuseIdentifier:kGenericBasicCellId];
    [self.tableView registerNib:[UINib nibWithNibName:kTagsViewCellId bundle:nil] forCellReuseIdentifier:kTagsViewCellId];
    
    self.customData = [[MutableOrderedDictionary alloc] init];
    NSArray* sortedKeys = [self.item.fields.customData.allKeys sortedArrayUsingComparator:finderStringComparator];
    for (NSString* key in sortedKeys) {
        ValueWithModDate* vm = self.item.fields.customData[key];
        [self.customData addKey:key andValue:vm.value];
    }
    
    self.notes = self.item.isGroup ? self.item.fields.notes : @"";
    
    [self loadDates];
    [self loadProperties];
}

- (void)loadProperties {
    self.properties = [[MutableOrderedDictionary alloc] init];
        
    NSString* value = keePassStringIdFromUuid(self.item.uuid);
    self.properties[@"ID"] = value;

    self.properties[NSLocalizedString(@"item_properties_search_visible_state", @"Visible in Search")] = localizedYesOrNoFromBool (self.item.isSearchable);
    
    if ( self.item.fields.previousParentGroup ) {
        self.properties[NSLocalizedString(@"item_properties_previous_parent_group", @"Previous Parent Group")] = keePassStringIdFromUuid(self.item.fields.previousParentGroup);
    }
    
    if (self.item.isGroup) {
        self.properties[NSLocalizedString(@"item_properties_allow_search", @"Allow Search")] = [self optionalBoolString:self.item.fields.enableSearching];
        self.properties[NSLocalizedString(@"item_properties_allow_autotype", @"Allow AutoType")] = [self optionalBoolString:self.item.fields.enableAutoType];
        self.properties[NSLocalizedString(@"item_properties_is_expanded", @"Is Expanded")] = localizedYesOrNoFromBool(self.item.fields.isExpanded);
        
        if (self.item.fields.defaultAutoTypeSequence.length) {
            self.properties[NSLocalizedString(@"item_properties_default_autotype_sequence", @"Default Auto Type Sequence")] = self.item.fields.defaultAutoTypeSequence;
        }
        
        if (self.item.fields.lastTopVisibleEntry && ![self.item.fields.lastTopVisibleEntry isEqual:NSUUID.zero]) {
            self.properties[NSLocalizedString(@"item_properties_last_top_visible_entry", @"Last Top Visible Entry")] = keePassStringIdFromUuid(self.item.fields.lastTopVisibleEntry);
        }
    }
    else {
        if ( !self.item.fields.qualityCheck ) {
            self.properties[NSLocalizedString(@"audit_status_item_is_exluded", @"This item is excluded from Audits")] = localizedYesOrNoFromBool(!self.item.fields.qualityCheck);
        }
        if (self.item.fields.foregroundColor.length) {
            self.properties[NSLocalizedString(@"item_properties_foreground_color", @"Foreground Color")] = self.item.fields.foregroundColor;
        }
        if (self.item.fields.backgroundColor.length) {
            self.properties[NSLocalizedString(@"item_properties_background_color", @"Background Color")] = self.item.fields.backgroundColor;
        }
        if (self.item.fields.overrideURL.length) {
            self.properties[NSLocalizedString(@"item_properties_override_url", @"Override URL")] = self.item.fields.overrideURL;
        }
        if (self.item.fields.autoType) {
            self.properties[NSLocalizedString(@"item_properties_autotype_enabled", @"AutoType Enabled")] = localizedYesOrNoFromBool (self.item.fields.autoType.enabled);
            self.properties[NSLocalizedString(@"item_properties_autotype_obfuscation", @"AutoType Obfuscation")] = @(self.item.fields.autoType.dataTransferObfuscation).stringValue;

            if (self.item.fields.autoType.defaultSequence.length) {
                self.properties[NSLocalizedString(@"item_properties_default_autotype_sequence", @"Default Auto Type Sequence")] = self.item.fields.autoType.defaultSequence;
            }
            
            if (self.item.fields.autoType.asssociations.count) {
                for (AutoTypeAssociation* association in self.item.fields.autoType.asssociations) {
                    NSString* twFmt = [NSString stringWithFormat:NSLocalizedString(@"item_properties_target_window_fmt", @"Target Window: [%@]"), association.window];
                    self.properties[twFmt] = association.keystrokeSequence.length ? association.keystrokeSequence : NSLocalizedString(@"item_properties_default_autotype_sequence", @"Default Auto Type Sequence");
                }
            }
        }
    }
}

- (NSString*)optionalBoolString:(NSNumber*)optBool {
    NSString* inherited = NSLocalizedString(@"generic_setting_is_inherited_from_parent", @"Inherited from Parent");
    return optBool == nil ? inherited : localizedYesOrNoFromBool ( optBool.boolValue );
}

- (void)loadDates {
    self.dates = [[MutableOrderedDictionary alloc] init];
    
    if (self.item.fields.created) {
        self.dates[NSLocalizedString(@"item_details_metadata_created_field_title", @"Created")] = self.item.fields.created.friendlyDateString;
    }
    
    if (self.item.fields.modified) {
        self.dates[NSLocalizedString(@"item_details_metadata_modified_field_title", @"Modified")] = self.item.fields.modified.friendlyDateString;
    }

    if ( self.model.database.originalFormat == kKeePass4 || self.model.database.originalFormat == kKeePass ) {
        if (self.item.fields.modified) {
            self.dates[NSLocalizedString(@"item_details_metadata_location_changed_field_title", @"Location Changed")] = self.item.fields.locationChanged.friendlyDateString;
        }
        if (self.item.fields.expires) {
            self.dates[NSLocalizedString(@"item_details_expires_field_title", @"Expires")] = self.item.fields.expires.friendlyDateString;
        }
    }
}
       
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return kSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if ( section == kSectionPropertiesIdx ) {
        return self.properties.count;
    }
    else if ( section == kSectionNotesIdx ) {
        return self.notes.length ? 1 : 0;
    }
    else if ( section == kSectionCustomDataIdx ) {
        return self.customData.count;
    }
    else if ( section == kSectionUuidIdx ) {
        return 1;
    }
    else if ( section == kSectionTagsIdx ) {
        return 1;
    }
    else if ( section == kSectionDatesIdx ) {
        return self.dates.count;
    }

    return [super tableView:tableView numberOfRowsInSection:section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ( indexPath.section == kSectionPropertiesIdx ) {
        NSString* key = self.properties.allKeys[indexPath.row];
        NSString* value = self.properties[key];
        
        GenericKeyValueTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kGenericKeyValueCellId forIndexPath:indexPath];

        [cell setKey:key value:value editing:NO useEasyReadFont:NO];

        return cell;
    }
    else if ( indexPath.section == kSectionNotesIdx ) {
        GenericBasicCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kGenericBasicCellId forIndexPath:indexPath];
        cell.labelText.text = [self maybeDereference:self.notes];
        return cell;
    }
    else if ( indexPath.section == kSectionCustomDataIdx ) {
        NSString* key = self.customData.allKeys[indexPath.row];
        NSString* value = self.customData[key];
        
        GenericKeyValueTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kGenericKeyValueCellId forIndexPath:indexPath];

        [cell setKey:key value:value editing:NO useEasyReadFont:NO];
        
        return cell;
    }
    else if ( indexPath.section == kSectionUuidIdx ) {
        NSString* key = @"ID";
        NSString* value = keePassStringIdFromUuid(self.item.uuid);
        
        GenericKeyValueTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kGenericKeyValueCellId forIndexPath:indexPath];

        [cell setKey:key value:value editing:NO useEasyReadFont:NO];
        
        return cell;
    }
    else if ( indexPath.section == kSectionDatesIdx ) {
        NSString* key = self.dates.allKeys[indexPath.row];
        NSString* value = self.dates[key];
        
        GenericKeyValueTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kGenericKeyValueCellId forIndexPath:indexPath];

        [cell setKey:key value:value editing:NO useEasyReadFont:NO];
        
        return cell;
    }
    else if ( indexPath.section == kSectionTagsIdx ) {
        return [self getTagsCell:indexPath];
    }
    
    return [super tableView:tableView cellForRowAtIndexPath:indexPath];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if ( section == kSectionPropertiesIdx && self.properties.count ) {
        return NSLocalizedString(@"properties_vc_header_basic", @"Properties");
    }
    else if ( section == kSectionNotesIdx  && self.notes.length ) {
        return NSLocalizedString(@"properties_vc_header_group_notes", @"Group Notes");
    }
    else if ( section == kSectionCustomDataIdx && self.customData.count ) {
        return NSLocalizedString(@"properties_vc_header_custom_data", @"Custom Data");
    }
    else if ( section == kSectionDatesIdx ) {
        return NSLocalizedString(@"properties_vc_header_dates", @"Dates");
    }
    
    return [super tableView:tableView titleForHeaderInSection:section];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {




    if ( section == kSectionNotesIdx && self.notes.length ) {
        return NSLocalizedString(@"properties_vc_footer_group_notes", @"Notes set on this group.");
    }
    else if ( section == kSectionCustomDataIdx && self.customData.count ) {
        return NSLocalizedString(@"properties_vc_footer_custom_data", @"Custom Data used by plugins and various other applications.");
    }

    return [super tableView:tableView titleForFooterInSection:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if ( section == kSectionNotesIdx && self.notes.length == 0 ) {
        return CGFLOAT_MIN;
    }
    else if ( section == kSectionCustomDataIdx && self.customData.count == 0 ) {
        return CGFLOAT_MIN;
    }
    else if ( section == kSectionPropertiesIdx && self.properties.count == 0) {
        return CGFLOAT_MIN;
    }
    else if ( section == kSectionTagsIdx && (!self.item.isGroup || self.item.fields.tags.count == 0 ) ) {
        return CGFLOAT_MIN;
    }

    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if ( section == kSectionNotesIdx && self.notes.length == 0 ) {
        return CGFLOAT_MIN;
    }
    else if ( section == kSectionCustomDataIdx && self.customData.count == 0 ) {
        return CGFLOAT_MIN;
    }
    else if ( section == kSectionPropertiesIdx && self.properties.count == 0) {
        return CGFLOAT_MIN;
    }
    else if ( section == kSectionTagsIdx && (!self.item.isGroup || self.item.fields.tags.count == 0 ) ) {
        return CGFLOAT_MIN;
    }

    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ( indexPath.section == kSectionNotesIdx && self.notes.length == 0 ) {
        return CGFLOAT_MIN;
    }
    else if ( indexPath.section == kSectionCustomDataIdx && self.customData.count == 0 ) {
        return CGFLOAT_MIN;
    }
    else if ( indexPath.section == kSectionPropertiesIdx && self.properties.count == 0) {
        return CGFLOAT_MIN;
    }
    else if ( indexPath.section == kSectionTagsIdx && ( !self.item.isGroup || self.item.fields.tags.count == 0 ) ) {
        return CGFLOAT_MIN;
    }

    return [super tableView:tableView heightForRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString* fmt = NSLocalizedString(@"mac_field_copied_to_clipboard_no_item_title_fmt", @"%@ Copied");

    if ( indexPath.section == kSectionNotesIdx ) {
        NSString* notes = NSLocalizedString(@"generic_fieldname_notes", @"Notes");
        [self copyToClipboard:[self maybeDereference:self.item.fields.notes] message:[NSString stringWithFormat:fmt, notes]];
    }
    else if ( indexPath.section == kSectionPropertiesIdx ) {
        NSString* key = self.properties.allKeys[indexPath.row];
        NSString* value = self.properties[key];
        [self copyToClipboard:value message:[NSString stringWithFormat:fmt, key]];
    }
    else if ( indexPath.section == kSectionCustomDataIdx ) {
        NSString* key = self.customData.allKeys[indexPath.row];
        NSString* value = self.customData[key];
        [self copyToClipboard:value message:[NSString stringWithFormat:fmt, key]];
    }
    else if ( indexPath.section == kSectionUuidIdx ) {
        NSString* key = @"ID";
        NSString* value = keePassStringIdFromUuid(self.item.uuid);
        [self copyToClipboard:value message:[NSString stringWithFormat:fmt, key]];
    }
    else if ( indexPath.section == kSectionDatesIdx ) {
        NSString* key = self.dates.allKeys[indexPath.row];
        NSString* value = self.dates[key];
        [self copyToClipboard:value message:[NSString stringWithFormat:fmt, key]];
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (NSString*)maybeDereference:(NSString*)text {
    return self.model.metadata.viewDereferencedFields ? [self.model.database dereference:text node:self.item] : text;
}

- (void)copyToClipboard:(NSString *)value message:(NSString *)message {
    if (value.length == 0) {
        return;
    }
    
    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:value];

#ifndef IS_APP_EXTENSION
    [ISMessages showCardAlertWithTitle:message
                               message:nil
                              duration:3.f
                           hideOnSwipe:YES
                             hideOnTap:YES
                             alertType:ISAlertTypeSuccess
                         alertPosition:ISAlertPositionTop
                               didHide:nil];
#endif
}

- (UITableViewCell*)getTagsCell:(NSIndexPath*)indexPath {
    TagsViewTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:kTagsViewCellId forIndexPath:indexPath];


    
    NSArray<NSString*>* tags = [self.item.fields.tags.allObjects sortedArrayUsingComparator:finderStringComparator];

    [cell setModel:YES
              tags:tags
   useEasyReadFont:self.model.metadata.easyReadFontForAll
             onAdd:nil
          onRemove:nil];

    return cell;
}

@end
