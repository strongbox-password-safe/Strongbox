//
//  NewEntryDefaultsHelper.m
//  MacBox
//
//  Created by Strongbox on 12/10/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

#import "NewEntryDefaultsHelper.h"
#import "Settings.h"
#import "NSString+Extensions.h"
#import "PasswordMaker.h"

@implementation NewEntryDefaultsHelper

+ (Node*)getDefaultNewEntryNode:(DatabaseModel*)database parentGroup:(Node *_Nonnull)parentGroup {
    AutoFillNewRecordSettings *autoFill = Settings.sharedInstance.autoFillNewRecordSettings;
    BOOL useParentGroupIcon = Settings.sharedInstance.useParentGroupIconOnCreate;
    
    
    
    NSString *actualTitle = autoFill.titleAutoFillMode == kDefault ? [self getDefaultTitle] :
    autoFill.titleAutoFillMode == kSmartUrlFill ? [self getSmartFillTitle] : autoFill.titleCustomAutoFill;
    
    
    
    NSString *actualUsername = autoFill.usernameAutoFillMode == kNone ? @"" :
    autoFill.usernameAutoFillMode == kMostUsed ? [self getAutoFillMostPopularUsername:database] : autoFill.usernameCustomAutoFill;
    
    
    
    NSString *actualPassword = autoFill.passwordAutoFillMode == kNone ? @"" : autoFill.passwordAutoFillMode == kGenerated ? [self generatePassword] : autoFill.passwordCustomAutoFill;
    
    
    
    NSString *actualEmail = autoFill.emailAutoFillMode == kNone ? @"" :
    autoFill.emailAutoFillMode == kMostUsed ? [self getAutoFillMostPopularEmail:database] : autoFill.emailCustomAutoFill;
    
    
    
    NSString *actualUrl = autoFill.urlAutoFillMode == kNone ? @"" :
    autoFill.urlAutoFillMode == kSmartUrlFill ? [self getSmartFillUrl] : autoFill.urlCustomAutoFill;
    
    
    
    NSString *actualNotes = autoFill.notesAutoFillMode == kNone ? @"" :
    autoFill.notesAutoFillMode == kClipboard ? [self getSmartFillNotes] : autoFill.notesCustomAutoFill;
    
    
    
    NodeFields* fields = [[NodeFields alloc] initWithUsername:actualUsername
                                                          url:actualUrl
                                                     password:actualPassword
                                                        notes:actualNotes
                                                        email:actualEmail];
    
    Node* record = [[Node alloc] initAsRecord:actualTitle parent:parentGroup fields:fields uuid:nil];
    
    if ( useParentGroupIcon && !parentGroup.isUsingKeePassDefaultIcon ) {
        record.icon = parentGroup.icon;
    }
    
    return record;
}

+ (NSString*)getDefaultTitle {
    return NSLocalizedString(@"item_details_vc_new_item_title", @"Untitled");
}

+ (NSString*)getSmartFillTitle {
    NSPasteboard*  myPasteboard  = [NSPasteboard generalPasteboard];
    NSString* clipboardText = [myPasteboard  stringForType:NSPasteboardTypeString];
    
    if(clipboardText) {
        
        
        NSURL *url = clipboardText.urlExtendedParse;
        
        if (url && url.scheme && url.host)
        {
            return url.host;
        }
    }
    
    return [self getDefaultTitle];
}

+ (NSString*)getSmartFillUrl {
    NSPasteboard*  myPasteboard  = [NSPasteboard generalPasteboard];
    NSString* clipboardText = [myPasteboard  stringForType:NSPasteboardTypeString];
    
    if(clipboardText) {
        NSURL *url = clipboardText.urlExtendedParse;
        if (url && url.scheme && url.host)
        {
            return clipboardText;
        }
    }
    
    return @"";
}

+ (NSString*)getSmartFillNotes {
    NSPasteboard*  myPasteboard  = [NSPasteboard generalPasteboard];
    NSString* clipboardText = [myPasteboard  stringForType:NSPasteboardTypeString];
    
    if(clipboardText) {
        return clipboardText;
    }
    
    return @"";
}

+ (NSString*)getAutoFillMostPopularUsername:(DatabaseModel*)database {
    return database.mostPopularUsername == nil ? @"" : database.mostPopularUsername;
}

+ (NSString*)getAutoFillMostPopularEmail:(DatabaseModel*)database {
    return database.mostPopularEmail == nil ? @"" : database.mostPopularEmail;
}

+ (NSString*)generatePassword {
    return [PasswordMaker.sharedInstance generateForConfigOrDefault:Settings.sharedInstance.passwordGenerationConfig];
}

@end
