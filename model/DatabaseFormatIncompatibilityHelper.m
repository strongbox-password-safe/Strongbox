//
//  DatabaseFormatIncompatibilityHelper.m
//  MacBox
//
//  Created by Strongbox on 28/07/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "DatabaseFormatIncompatibilityHelper.h"
#import "NSArray+Extensions.h"
#import "Constants.h"

@implementation DatabaseFormatIncompatibilityHelper

+ (void)processFormatIncompatibilities:(NSArray<Node *> *)nodes
                destinationIsRootGroup:(BOOL)destinationIsRootGroup
                          sourceFormat:(DatabaseFormat)sourceFormat
                     destinationFormat:(DatabaseFormat)destinationFormat
                   confirmChangesBlock:(IncompatibilityConfirmChangesBlock)confirmChangesBlock
                            completion:(IncompatibilityCompletionBlock)completion {
    if (sourceFormat == kPasswordSafe && (destinationFormat == kKeePass || destinationFormat == kKeePass4)) {
        [DatabaseFormatIncompatibilityHelper processPasswordSafeToKeePass2:nodes completion:completion];
    }
    else if (sourceFormat == kPasswordSafe && destinationFormat == kKeePass1) {
        [DatabaseFormatIncompatibilityHelper processPasswordSafeToKeePass1:nodes destinationIsRootGroup:destinationIsRootGroup confirmChangesBlock:confirmChangesBlock completion:completion];
    }
    else if ((sourceFormat == kKeePass || sourceFormat == kKeePass4) && destinationFormat == kPasswordSafe) {
        [DatabaseFormatIncompatibilityHelper processKeePass2ToPasswordSafe:nodes confirmChangesBlock:confirmChangesBlock completion:completion];
    }
    else if ((sourceFormat == kKeePass || sourceFormat == kKeePass4) && destinationFormat == kKeePass1) {
        [DatabaseFormatIncompatibilityHelper processKeePass2ToKeePass1:nodes destinationIsRootGroup:destinationIsRootGroup confirmChangesBlock:confirmChangesBlock completion:completion];
    }
    else if (sourceFormat == kKeePass1 && destinationFormat == kPasswordSafe) {
        [DatabaseFormatIncompatibilityHelper processKeePass1ToPasswordSafe:nodes confirmChangesBlock:confirmChangesBlock completion:completion];
    }
    else {
        completion(YES, nodes);
    }
}

+ (void)processPasswordSafeToKeePass2:(NSArray<Node*>*)nodes
                           completion:(IncompatibilityCompletionBlock)completion {
    NSArray<Node*>* ret = [DatabaseFormatIncompatibilityHelper processPasswordSafeToKeePass2:nodes];
    
    completion(YES, ret);
}

+ (NSArray<Node*>*)processPasswordSafeToKeePass2:(NSArray<Node*>*)nodes {
    
    
    NSArray<Node*>* allRecords = [nodes flatMap:^NSArray * _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return obj.allChildRecords;
    }];
    NSMutableArray<Node*>* all = allRecords.mutableCopy;
    [all addObjectsFromArray:nodes];
    NSArray<Node*>* nodesWithEmails = [all filter:^BOOL(Node * _Nonnull obj) {
        return obj.fields.email.length;
    }];
    
    if ( nodesWithEmails.count ) {
        for (Node* nodeWithEmail in nodesWithEmails) {
           [nodeWithEmail.fields setCustomField:kCanonicalEmailFieldName value:[StringValue valueWithString:nodeWithEmail.fields.email]];
        }
    }
    
    return nodes;
}

+ (void)processPasswordSafeToKeePass1:(NSArray<Node*>*)nodes
               destinationIsRootGroup:(BOOL)destinationIsRootGroup
                  confirmChangesBlock:(IncompatibilityConfirmChangesBlock)confirmChangesBlock
                           completion:(IncompatibilityCompletionBlock)completion {
    
   
    NSArray<Node*>* allRecords = [nodes flatMap:^NSArray * _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return obj.allChildRecords;
    }];
    NSMutableArray<Node*>* all = allRecords.mutableCopy;
    [all addObjectsFromArray:nodes];
    NSArray<Node*>* nodesWithEmails = [all filter:^BOOL(Node * _Nonnull obj) {
        return obj.fields.email.length;
    }];
    
    NSArray<Node*>* rootEntries = [nodes filter:^BOOL(Node * _Nonnull obj) {
        return !obj.isGroup;
    }];
    
    BOOL pastingEntriesToRoot = ( destinationIsRootGroup && rootEntries.count );
    
    if(nodesWithEmails.count || pastingEntriesToRoot) {
        NSString* loc = NSLocalizedString(@"mac_keepass1_does_not_support_root_entries", @"KeePass 1 does not support entries at the root level, these will be discarded. KeePass 1 also does not natively support the 'Email' field. Strongbox will append it instead to the end of the 'Notes' field.\nDo you want to continue?");
        
        confirmChangesBlock ( loc, ^(BOOL go) {
            if ( go ) {
                for (Node* nodeWithEmail in nodesWithEmails) {
                    nodeWithEmail.fields.notes = [nodeWithEmail.fields.notes stringByAppendingFormat:@"%@Email: %@",
                                                  nodeWithEmail.fields.notes.length ? @"\n\n" : @"",
                                                  nodeWithEmail.fields.email];
                }

                NSArray* filtered = nodes;
                if ( pastingEntriesToRoot ) {
                    filtered = [nodes filter:^BOOL(Node * _Nonnull obj) {
                        return obj.isGroup;
                    }];
                }

                completion ( YES, filtered );
            }
            else {
                completion ( NO, nil );
            }
        });
    }
    else {
        completion(YES, nodes);
    }
}

+ (void)processKeePass2ToPasswordSafe:(NSArray<Node*>*)nodes
                  confirmChangesBlock:(IncompatibilityConfirmChangesBlock)confirmChangesBlock
                           completion:(IncompatibilityCompletionBlock)completion {
    
    
    NSArray<Node*>* allChildNodes = [nodes flatMap:^NSArray * _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return obj.children;
    }];
    NSMutableArray<Node*>* all = allChildNodes.mutableCopy;
    [all addObjectsFromArray:nodes];
    
    NSArray<Node*>* incompatibles = [all filter:^BOOL(Node * _Nonnull obj) {
        BOOL customIcon = !obj.isUsingKeePassDefaultIcon;
        BOOL attachments = obj.fields.attachments.count;
        BOOL customFields = obj.fields.customFields.count;
        
        return customIcon || attachments || customFields;
    }];

    if(incompatibles.count) {
        NSString* loc = NSLocalizedString(@"mac_password_safe_fmt_does_not_support_icons_attachments_warning", @"The Password Safe format does not support icons, attachments or custom fields. If you continue, these fields will not be copied to this database.\nDo you want to continue without these fields?");

        confirmChangesBlock ( loc, ^(BOOL go) {
            if ( go ) {
                for (Node* incompatible in incompatibles) {
                    incompatible.icon = nil;
                    [incompatible.fields.attachments removeAllObjects];
                    [incompatible.fields removeAllCustomFields];
                }

                completion(YES, nodes);
            }
            else {
                completion ( NO, nil );
            }
        });
    }
    else {
        completion(YES, nodes);
    }
}

+ (void)processKeePass2ToKeePass1:(NSArray<Node*>*)nodes
           destinationIsRootGroup:(BOOL)destinationIsRootGroup
              confirmChangesBlock:(IncompatibilityConfirmChangesBlock)confirmChangesBlock
                       completion:(IncompatibilityCompletionBlock)completion {
    

    NSArray<Node*>* allChildNodes = [nodes flatMap:^NSArray * _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return obj.children;
    }];
    NSMutableArray<Node*>* all = allChildNodes.mutableCopy;
    [all addObjectsFromArray:nodes];

    NSArray<Node*>* incompatibles = [all filter:^BOOL(Node * _Nonnull obj) {
        BOOL customIcon = obj.icon.isCustom;
        BOOL tooManyAttachments = obj.fields.attachments.count > 1;
        BOOL customFields = obj.fields.customFields.count;
        
        return customIcon || tooManyAttachments || customFields;
    }];

    NSArray<Node*>* rootEntries = [nodes filter:^BOOL(Node * _Nonnull obj) {
        return !obj.isGroup;
    }];
    BOOL pastingEntriesToRoot = (destinationIsRootGroup && rootEntries.count);

    if(incompatibles.count || pastingEntriesToRoot) {
        NSString* loc = NSLocalizedString(@"mac_keepass1_does_not_support_root_entries_or_attachments", @"The KeePass 1 (KDB) does not support entries at the root level, these will be discarded.\n\nThe KeePass 1 (KDB) format also does not support multiple attachments, custom fields or custom icons. If you continue only the first attachment from each item will be copied to this database. Custom Fields and Icons will be discarded.\nDo you want to continue?");

        confirmChangesBlock ( loc, ^(BOOL go) {
            if ( go ) {
                for (Node* incompatible in incompatibles) {
                    incompatible.icon = nil;
                    NSString* firstAttachmentFilename = incompatible.fields.attachments.allKeys.firstObject;
                    if ( firstAttachmentFilename ) {
                        KeePassAttachmentAbstractionLayer* dbA = incompatible.fields.attachments[firstAttachmentFilename];
                        
                        [incompatible.fields.attachments removeAllObjects];
                        
                        incompatible.fields.attachments[firstAttachmentFilename] = dbA;
                    }
                    else {
                        [incompatible.fields.attachments removeAllObjects];
                    }
                    [incompatible.fields removeAllCustomFields];
                }
                
                NSArray* filtered = nodes;
                if(pastingEntriesToRoot) {
                    filtered = [nodes filter:^BOOL(Node * _Nonnull obj) {
                        return obj.isGroup;
                    }];
                }
                
                completion( YES, filtered );
            }
            else {
                completion ( NO, nil );
            }
        });
    }
    else {
        completion(YES, nodes);
    }
}

+ (void)processKeePass1ToPasswordSafe:(NSArray<Node*>*)nodes
                  confirmChangesBlock:(IncompatibilityConfirmChangesBlock)confirmChangesBlock
                           completion:(IncompatibilityCompletionBlock)completion {
    
    
    NSArray<Node*>* allChildNodes = [nodes flatMap:^NSArray * _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return obj.children;
    }];
    NSMutableArray<Node*>* all = allChildNodes.mutableCopy;
    [all addObjectsFromArray:nodes];
    
    NSArray<Node*>* incompatibles = [all filter:^BOOL(Node * _Nonnull obj) {
        BOOL customIcon = !obj.isUsingKeePassDefaultIcon;
        BOOL attachments = obj.fields.attachments.count;
        
        return customIcon || attachments;
    }];
    
    if(incompatibles.count) {
        NSString* loc = NSLocalizedString(@"mac_password_safe_does_not_support_attachments_icons_continue_yes_no", @"The Password Safe format does not support attachments or icons. If you continue, these fields will not be copied to this database.\nDo you want to continue without these fields?");
        
        confirmChangesBlock ( loc, ^(BOOL go) {
            if ( go ) {
                for (Node* incompatible in incompatibles) {
                    incompatible.icon = nil;
                    [incompatible.fields.attachments removeAllObjects];
                    [incompatible.fields removeAllCustomFields];
                }

                completion(YES, nodes);
            }
            else {
                completion ( NO, nil );
            }
        });
    }
    else {
        completion(YES, nodes);
    }
}

@end
