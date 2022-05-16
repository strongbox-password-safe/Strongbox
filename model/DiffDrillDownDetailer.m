//
//  DiffDrillDownDetailer.m
//  MacBox
//
//  Created by Strongbox on 06/05/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import "DiffDrillDownDetailer.h"
#import "Utils.h"
#import "NSArray+Extensions.h"
#import "NSDate+Extensions.h"

@implementation DiffDrillDownDetailer

+ (MutableOrderedDictionary<NSString*, NSString*> *)initializePropertiesDiff:(DatabaseModel*)firstDatabase
                                                              secondDatabase:(DatabaseModel*)secondDatabase
                                                                 isMergeDiff:(BOOL)isMergeDiff {
    MutableOrderedDictionary<NSString*, NSString*> *diffs = [[MutableOrderedDictionary alloc] init];

    UnifiedDatabaseMetadata* me = firstDatabase.meta;
    UnifiedDatabaseMetadata* thee = secondDatabase.meta;

    NSString* prevNew = isMergeDiff ? NSLocalizedString(@"diff_drill_down_previous_new_fmt", @"From %@ to %@") : NSLocalizedString(@"diff_drill_down_first_vs_second_fmt", @"%@ <> %@");
    
    BOOL colorDifferent = !((me.color.length == 0 && thee.color.length == 0) || (me.color && [me.color compare:thee.color] == NSOrderedSame));
    if ( colorDifferent ) {
        NSString* foo = isMergeDiff ? NSLocalizedString(@"diff_drill_down_color_will_change", @"Color will change.") : NSLocalizedString(@"diff_drill_down_color_is_different", @"Color is different.");
        diffs[foo] = [NSString stringWithFormat:prevNew, me.color, thee.color];
    }
    
    BOOL nameDifferent = !((me.databaseName.length == 0 && thee.databaseName.length == 0) || (me.databaseName && [me.databaseName compare:thee.databaseName] == NSOrderedSame));
    if ( nameDifferent ) {
        NSString* foo = isMergeDiff ? NSLocalizedString(@"diff_drill_down_database_name_will_change", @"Database Name will change.") : NSLocalizedString(@"diff_drill_down_database_name_is_different", @"Database Name is different.") ;
        diffs[foo] = [NSString stringWithFormat:prevNew, me.databaseName, thee.databaseName];
    }
    
    BOOL descDifferent = !((me.databaseDescription.length == 0 && thee.databaseDescription.length == 0) || (me.databaseDescription && [me.databaseDescription compare:thee.databaseDescription] == NSOrderedSame));
    if ( descDifferent ) {
        NSString* foo = isMergeDiff ? NSLocalizedString(@"diff_drill_down_database_desc_will_change", @"Database Description will change.") : NSLocalizedString(@"diff_drill_down_database_desc_is_different", @"Database Description is different.");
        diffs[foo] = [NSString stringWithFormat:prevNew, me.databaseDescription, thee.databaseDescription];
    }
    
    BOOL usernameDifferent = !((me.defaultUserName.length == 0 && thee.defaultUserName.length == 0) || (me.defaultUserName && [me.defaultUserName compare:thee.defaultUserName] == NSOrderedSame));
    if ( usernameDifferent ) {
        NSString* foo = isMergeDiff ? NSLocalizedString(@"diff_drill_down_default_username_will_change", @"Default Username date will change.") : NSLocalizedString(@"diff_drill_down_default_username_is_different", @"Default Username date is different.");
        diffs[foo] = [NSString stringWithFormat:prevNew, me.defaultUserName, thee.defaultUserName];
    }
    
    BOOL recycleBinDifferent = !(me.recycleBinEnabled == thee.recycleBinEnabled);
    if ( recycleBinDifferent ) {
        NSString* foo = isMergeDiff ? NSLocalizedString(@"diff_drill_down_recycle_bin_enabled_will_change", @"Recycle Bin Enabled state will change.") : NSLocalizedString(@"diff_drill_down_recycle_bin_enabled_is_different", @"Recycle Bin Enabled state is different.");
        diffs[foo] = [NSString stringWithFormat:prevNew, localizedYesOrNoFromBool(me.recycleBinEnabled), localizedYesOrNoFromBool(thee.recycleBinEnabled)];
    }
    
    BOOL customDataDifferent = ![me.customData isEqualToDictionary:thee.customData];
    if ( customDataDifferent ) {
        NSMutableSet<NSString*> *allKeys = thee.customData.allKeys.set.mutableCopy;
        [allKeys unionSet:me.customData.allKeys.set];

        for (NSString* key in allKeys) {
            ValueWithModDate* m = me.customData[key];
            ValueWithModDate* t = thee.customData[key];

            if (m && t) {
                if (t && ![m isEqual:t]) {
                    NSString* foo = isMergeDiff ? NSLocalizedString(@"diff_drill_down_custom_data_will_change_fmt", @"Custom Data %@ will change.") : NSLocalizedString(@"diff_drill_down_custom_data_is_different_fmt", @"Custom Data %@ is different.");
                    NSString* k = [NSString stringWithFormat:foo, key];
                    diffs[k] = [NSString stringWithFormat:prevNew, m.value, t.value];
                }
            }
            else if (m) {
                NSString* k = isMergeDiff ? NSLocalizedString(@"diff_drill_down_custom_data_will_be_removed_fmt", @"Custom Data item will be removed.") : NSLocalizedString(@"diff_drill_down_custom_data_is_only_in_first", @"Custom Data is only in first.");
                NSString* foo = NSLocalizedString(@"diff_drill_down_custom_data_new_entry_key_value", @"%@ -> %@");
                diffs[k] = [NSString stringWithFormat:foo, key, m];
            }
            else { 
                NSString* k = isMergeDiff ? NSLocalizedString(@"diff_drill_down_custom_data_will_be_added_fmt", @"Custom Data item will be added.") : NSLocalizedString(@"diff_drill_down_custom_data_is_only_in_second", @"Custom Data is only in second.");
                NSString* foo = NSLocalizedString(@"diff_drill_down_custom_data_new_entry_key_value", @"%@ -> %@");
                diffs[k] = [NSString stringWithFormat:foo, key, t];
            }
        }
    }
    
    return diffs;
}

+ (MutableOrderedDictionary<NSString*, NSString*> *)initializePairWiseDiffs:(DatabaseModel*)firstDatabase
                                                             secondDatabase:(DatabaseModel*)secondDatabase
                                                                   diffPair:(MMcGPair<Node*, Node*>*)diffPair isMergeDiff:(BOOL)isMergeDiff {
    MutableOrderedDictionary<NSString*, NSString*> *diffs = [[MutableOrderedDictionary alloc] init];

    Node* mine = diffPair.a;
    Node* other = diffPair.b;
    
    if (! [mine.uuid isEqual:other.uuid] ) {
        diffs[@"WARNWARN: Diff Pair have different UUIDs - Something very wrong - Please contact support@strongboxsafe.com"] = @"";
        return diffs;
    }
    
    NSString* prevNew = isMergeDiff ? NSLocalizedString(@"diff_drill_down_previous_new_fmt", @"From %@ to %@") : NSLocalizedString(@"diff_drill_down_first_vs_second_fmt", @"%@ <> %@");
        
    
    
    if ( [mine.title compare:other.title] != NSOrderedSame ) {
        NSString* locKey = isMergeDiff ? NSLocalizedString(@"diff_drill_down_title_change", @"Title will change.") : NSLocalizedString(@"diff_drill_down_titles_are_different", @"Titles are different.");
        diffs[locKey] = [NSString stringWithFormat:prevNew, mine.title, other.title];
    }

    
    
    if (!(other.parent == nil && mine.parent == nil) && 
        !(other.parent == secondDatabase.rootNode && mine.parent == firstDatabase.rootNode) && 
        !(other.parent && mine.parent && [other.parent.uuid isEqual:mine.parent.uuid])) {
        NSString* myLoc = [firstDatabase getSearchParentGroupPathDisplayString:mine];
        NSString* theirLoc = [secondDatabase getSearchParentGroupPathDisplayString:other];
        NSString* locKey = isMergeDiff ? NSLocalizedString(@"diff_drill_down_location_will_change", @"Item will be moved.") : NSLocalizedString(@"diff_drill_down_locations_are_different", @"Item locations are different.");
        NSString* bar = isMergeDiff ? prevNew : NSLocalizedString(@"diff_drill_down_diff_loc_different", @"In %@ and %@");
        diffs[locKey] = [NSString stringWithFormat:bar, myLoc, theirLoc];
    }

    

    if (mine.isGroup) {
        
        BOOL ret = [other.fields.modified isLaterThan:mine.fields.modified]; 

        if (ret) {
            NSString* locKey = isMergeDiff ? NSLocalizedString(@"diff_drill_down_mod_will_change", @"Modified Date will change.") : NSLocalizedString(@"diff_drill_down_mods_are_different", @"Modified Dates are different.");
            diffs[locKey] = [NSString stringWithFormat:prevNew, mine.fields.modified.friendlyDateTimeString, other.fields.modified.friendlyDateTimeString];
        }
        
        return diffs;
    }
    
    
    
    if (!( mine.isUsingKeePassDefaultIcon && other.isUsingKeePassDefaultIcon ) ) {
        if ( mine.icon != nil ) {
            if ( ![mine.icon isEqual:other.icon] ) {
                NSString* locKey = isMergeDiff ? NSLocalizedString(@"diff_drill_down_icons_will_change", @"Icons will change.") : NSLocalizedString(@"diff_drill_down_icons_are_different", @"Icons are different.");
                diffs[locKey] = @"";
            }
        }
        else if ( other.icon != nil ) {
            if ( ![other.icon isEqual:mine.icon] ) {
                NSString* locKey = isMergeDiff ? NSLocalizedString(@"diff_drill_down_icons_will_change", @"Icons will change.") : NSLocalizedString(@"diff_drill_down_icons_are_different", @"Icons are different.");
                diffs[locKey] = @"";
            }
        }
        else { } 
    }
    
    

    NSString* locKey = isMergeDiff ? NSLocalizedString(@"diff_drill_down_username_will_change", @"Username will change.") : NSLocalizedString(@"diff_drill_down_usernames_are_different", @"Username will change.");
    if ( [mine.fields.username compare:other.fields.username] != NSOrderedSame ) { diffs[locKey] = [NSString stringWithFormat:prevNew, mine.fields.username, other.fields.username]; }
        
    locKey = isMergeDiff ? NSLocalizedString(@"diff_drill_down_password_will_change", @"Password will change.") : NSLocalizedString(@"diff_drill_down_passwords_are_different", @"Password will change.");
    if ( [mine.fields.password compare:other.fields.password] != NSOrderedSame ) { diffs[locKey] = [NSString stringWithFormat:prevNew, mine.fields.password, other.fields.password]; }
        
    locKey = isMergeDiff ? NSLocalizedString(@"diff_drill_down_url_will_change", @"URL will change.") : NSLocalizedString(@"diff_drill_down_urls_are_different", @"URLs are different.");
    if ( [mine.fields.url compare:other.fields.url] != NSOrderedSame ) { diffs[locKey] = [NSString stringWithFormat:prevNew, mine.fields.url, other.fields.url]; }
        
    locKey = isMergeDiff ? NSLocalizedString(@"diff_drill_down_notes_will_change", @"Notes will change.") : NSLocalizedString(@"diff_drill_down_notes_are_different", @"Notes are different.");
    if ( [mine.fields.notes compare:other.fields.notes] != NSOrderedSame ) { diffs[locKey] = [NSString stringWithFormat:prevNew, mine.fields.notes, other.fields.notes]; }

    locKey = isMergeDiff ? NSLocalizedString(@"diff_drill_down_is_expanded_will_change", @"Expanded Group State will change.") : NSLocalizedString(@"diff_drill_down_expanded_states_are_different", @"Expanded Group States are different.");
    if ( mine.fields.isExpanded != other.fields.isExpanded ) { diffs[locKey] = [NSString stringWithFormat:prevNew, localizedYesOrNoFromBool(mine.fields.isExpanded), localizedYesOrNoFromBool(other.fields.isExpanded)]; }

    locKey = isMergeDiff ? NSLocalizedString(@"diff_drill_down_email_will_change", @"Email will change.") : NSLocalizedString(@"diff_drill_down_emails_are_different", @"Email will change.");
    if ( [mine.fields.email compare:other.fields.email] != NSOrderedSame ) { diffs[locKey] = [NSString stringWithFormat:prevNew, mine.fields.email, other.fields.email]; }
    
    if ((mine.fields.created == nil && other.fields.created != nil) || (mine.fields.created != nil && ![mine.fields.created isEqualToDate:other.fields.created] ))     {
        NSString* locKey = isMergeDiff ? NSLocalizedString(@"diff_drill_down_create_date_will_change", @"Created Date will change.") : NSLocalizedString(@"diff_drill_down_created_dates_are_different", @"Created Dates are different.");
        diffs[locKey] = [NSString stringWithFormat:prevNew, mine.fields.created.friendlyDateTimeString, other.fields.created.friendlyDateTimeString];
    }

    if ((mine.fields.modified == nil && other.fields.modified != nil) || (mine.fields.modified != nil && ![mine.fields.modified isEqualToDate:other.fields.modified] ))     {
        NSString* locKey = isMergeDiff ? NSLocalizedString(@"diff_drill_down_mod_date_will_change", @"Modified Date will change.") : NSLocalizedString(@"diff_drill_down_mod_dates_are_different", @"Modified Dates are different.");
        diffs[locKey] = [NSString stringWithFormat:prevNew, mine.fields.modified.friendlyDateTimeString, other.fields.modified.friendlyDateTimeString];
    }

    if ((mine.fields.expires == nil && other.fields.expires != nil) || (mine.fields.expires != nil && ![mine.fields.expires isEqualToDate:other.fields.expires] )) {
        NSString* locKey = isMergeDiff ? NSLocalizedString(@"diff_drill_down_expiry_date_will_change", @"Expiry Date will change.") : NSLocalizedString(@"diff_drill_down_expiry_are_different", @"Expiry Dates are different.");
        diffs[locKey] = [NSString stringWithFormat:prevNew, mine.fields.expires.friendlyDateTimeString, other.fields.expires.friendlyDateTimeString];
    }
        
    if ((mine.fields.foregroundColor.length == 0 && other.fields.foregroundColor.length) || (mine.fields.foregroundColor.length && ![mine.fields.foregroundColor isEqualToString:other.fields.foregroundColor] )) {
        NSString* locKey = isMergeDiff ? NSLocalizedString(@"diff_drill_down_foreground_color_will_change", @"Foreground Color will change.") : NSLocalizedString(@"diff_drill_down_foreground_color_are_different", @"Foreground Colors are different.");
        diffs[locKey] = [NSString stringWithFormat:prevNew, mine.fields.foregroundColor, other.fields.foregroundColor];
    }
    
    if ((mine.fields.backgroundColor.length == 0 && other.fields.backgroundColor.length) || (mine.fields.backgroundColor.length && ![mine.fields.backgroundColor isEqualToString:other.fields.backgroundColor] )) {
        NSString* locKey = isMergeDiff ? NSLocalizedString(@"diff_drill_down_background_color_will_change", @"Background Color will change.") : NSLocalizedString(@"diff_drill_down_background_color_are_different", @"Background Colors are different.");
        diffs[locKey] = [NSString stringWithFormat:prevNew, mine.fields.backgroundColor, other.fields.backgroundColor];
    }
    
    if ((mine.fields.overrideURL.length == 0 && other.fields.overrideURL.length) || (mine.fields.overrideURL.length && ![mine.fields.overrideURL isEqualToString:other.fields.overrideURL] )) {
        NSString* locKey = isMergeDiff ? NSLocalizedString(@"diff_drill_down_override_url_will_change", @"Override URL will change.") : NSLocalizedString(@"diff_drill_down_override_url_are_different", @"Override URLs are different.");
        diffs[locKey] = [NSString stringWithFormat:prevNew, mine.fields.overrideURL, other.fields.overrideURL];
    }
    
    if ( ![AutoType isDefault:mine.fields.autoType] || ![AutoType isDefault:other.fields.autoType]) {
        if ((mine.fields.autoType == nil && other.fields.autoType != nil) || (mine.fields.autoType != nil && ![mine.fields.autoType isEqual:other.fields.autoType])) {
            NSString* locKey = isMergeDiff ? NSLocalizedString(@"diff_drill_down_autotype_will_change", @"AutoType will change.") : NSLocalizedString(@"diff_drill_down_autotype_are_different", @"AutoTypes are different.");
            diffs[locKey] = [NSString stringWithFormat:prevNew, mine.fields.autoType, other.fields.autoType];
        }
    }
    
    if ( mine.fields.qualityCheck != other.fields.qualityCheck ) {
        NSString* locKey = isMergeDiff ? NSLocalizedString(@"diff_drill_down_audit_exclusion_will_change", @"Audit Exclusion State (Quality Check) will change.") : NSLocalizedString(@"diff_drill_down_audit_exclusion_are_different", @"Audit Exclusion State (Quality Check) is different.");
        diffs[locKey] = [NSString stringWithFormat:prevNew, localizedYesOrNoFromBool (mine.fields.qualityCheck), localizedYesOrNoFromBool ( other.fields.qualityCheck )];
    }
    
    
    
    BOOL customDataDifferent = ![mine.fields.customData isEqualToDictionary:other.fields.customData];
    if ( customDataDifferent ) {
        NSMutableSet<NSString*> *allKeys = other.fields.customData.allKeys.set.mutableCopy;
        [allKeys unionSet:mine.fields.customData.allKeys.set];

        for (NSString* key in allKeys) {
            ValueWithModDate* m = mine.fields.customData[key];
            ValueWithModDate* t = other.fields.customData[key];

            if (m && t) {
                if ( t && ![m isEqual:t] ) {
                    NSString* foo = isMergeDiff ? NSLocalizedString(@"diff_drill_down_custom_data_will_change_fmt", @"Custom Data %@ will change.") : NSLocalizedString(@"diff_drill_down_custom_data_is_different_fmt", @"Custom Data %@ is different.");
                    NSString* k = [NSString stringWithFormat:foo, key];
                    diffs[k] = [NSString stringWithFormat:prevNew, m.value, t.value];
                }
            }
            else if (m) {
                NSString* k = isMergeDiff ? NSLocalizedString(@"diff_drill_down_custom_data_will_be_removed_fmt", @"Custom Data item will be removed.") : NSLocalizedString(@"diff_drill_down_custom_data_is_only_in_first", @"Custom Data is only in first.");
                NSString* foo = NSLocalizedString(@"diff_drill_down_custom_data_new_entry_key_value", @"%@ -> %@");
                diffs[k] = [NSString stringWithFormat:foo, key, m];
            }
            else { 
                NSString* k = isMergeDiff ? NSLocalizedString(@"diff_drill_down_custom_data_will_be_added_fmt", @"Custom Data item will be added.") : NSLocalizedString(@"diff_drill_down_custom_data_is_only_in_second", @"Custom Data is only in second.");
                NSString* foo = NSLocalizedString(@"diff_drill_down_custom_data_new_entry_key_value", @"%@ -> %@");
                diffs[k] = [NSString stringWithFormat:foo, key, t];
            }
        }
    }
    
    
    
    if (![mine.fields.attachments isEqualToDictionary:other.fields.attachments]) {
        NSString* locKey = isMergeDiff ? NSLocalizedString(@"diff_drill_down_attachments_will_change", @"Attachments will change.") : NSLocalizedString(@"diff_drill_down_attachments_are_different", @"Attachments are different.");
        diffs[locKey] = @"";
    }

    

    if ( ![mine.fields.tags isEqualToSet:other.fields.tags] ) {
        NSString* locKey = isMergeDiff ? NSLocalizedString(@"diff_drill_down_tags_will_change", @"Tags will change.") : NSLocalizedString(@"diff_drill_down_tags_are_different", @"Tags are different.");
        diffs[locKey] = @"";
    }
    
    
    
    if (![mine.fields.customFields isEqual:other.fields.customFields]) {
        NSString* locKey = isMergeDiff ? NSLocalizedString(@"diff_drill_down_custom_fields_will_change", @"Custom Fields will change.") : NSLocalizedString(@"diff_drill_down_custom_fields_are_different", @"Custom Fields are different.");
        diffs[locKey] = @"";
    }
    
    return diffs;
}

@end
