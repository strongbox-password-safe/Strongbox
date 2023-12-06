//
//  AutoFillNewRecordSettings.m
//  Strongbox-iOS
//
//  Created by Mark on 04/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "AutoFillNewRecordSettings.h"
#import "SecretStore.h"

static NSString* const kNewEntryDefaultsCustomTitle = @"Strongbox-NewEntryDefaults-Custom-Title";
static NSString* const kNewEntryDefaultsCustomUsername = @"Strongbox-NewEntryDefaults-Custom-Username";
static NSString* const kNewEntryDefaultsCustomPassword = @"Strongbox-NewEntryDefaults-Custom-Password";
static NSString* const kNewEntryDefaultsCustomEmail = @"Strongbox-NewEntryDefaults-Custom-Email";
static NSString* const kNewEntryDefaultsCustomUrl = @"Strongbox-NewEntryDefaults-Custom-Url";
static NSString* const kNewEntryDefaultsCustomNotes = @"Strongbox-NewEntryDefaults-Custom-Notes";

@implementation AutoFillNewRecordSettings

+ (instancetype)defaults {
    AutoFillNewRecordSettings *defaultInstance = [[AutoFillNewRecordSettings alloc] init];
        
    defaultInstance.titleAutoFillMode = kDefault;
    defaultInstance.titleCustomAutoFill = NSLocalizedString(@"defaults_model_custom_title_default", @"Custom Title Default Text");
    
    defaultInstance.usernameAutoFillMode = kMostUsed;
    defaultInstance.usernameCustomAutoFill = NSLocalizedString(@"defaults_model_custom_username_default", @"Custom Username Default Text");
    
    defaultInstance.passwordAutoFillMode = kGenerated;
    defaultInstance.passwordCustomAutoFill = NSLocalizedString(@"defaults_model_custom_password_default", @"Custom Password Default Text");
    
    defaultInstance.emailAutoFillMode = kNone;
    defaultInstance.emailCustomAutoFill = NSLocalizedString(@"defaults_model_custom_email_default", @"Custom Email Default Text");
    
    defaultInstance.urlAutoFillMode = kNone;
    defaultInstance.urlCustomAutoFill = NSLocalizedString(@"defaults_model_custom_url_default", @"Custom URL Default Text");
    
    defaultInstance.notesAutoFillMode = kNone;
    defaultInstance.notesCustomAutoFill = NSLocalizedString(@"defaults_model_custom_notes_default", @"Custom Notes Default Text");
    
    return defaultInstance;
}

- (void)encodeWithCoder:(NSCoder *)aCoder{
    [aCoder encodeObject:@(self.titleAutoFillMode) forKey:@"titleAutoFillMode"];
    [aCoder encodeObject:@(self.usernameAutoFillMode) forKey:@"usernameAutoFillMode"];
    [aCoder encodeObject:@(self.passwordAutoFillMode) forKey:@"passwordAutoFillMode"];
    [aCoder encodeObject:@(self.emailAutoFillMode) forKey:@"emailAutoFillMode"];
    [aCoder encodeObject:@(self.urlAutoFillMode) forKey:@"urlAutoFillMode"];
    [aCoder encodeObject:@(self.notesAutoFillMode) forKey:@"notesAutoFillMode"];
}

-(id)initWithCoder:(NSCoder *)aDecoder{
    if(self = [super init]){
        NSNumber* obj = [aDecoder decodeObjectForKey:@"titleAutoFillMode"];
        self.titleAutoFillMode = (AutoFillMode)obj.longValue;
        self.usernameAutoFillMode = (AutoFillMode)((NSNumber*)[aDecoder decodeObjectForKey:@"usernameAutoFillMode"]).longValue;
        self.passwordAutoFillMode = (AutoFillMode)((NSNumber*)[aDecoder decodeObjectForKey:@"passwordAutoFillMode"]).longValue;
        self.emailAutoFillMode = (AutoFillMode)((NSNumber*)[aDecoder decodeObjectForKey:@"emailAutoFillMode"]).longValue;
        self.urlAutoFillMode = (AutoFillMode)((NSNumber*)[aDecoder decodeObjectForKey:@"urlAutoFillMode"]).longValue;
        self.notesAutoFillMode = (AutoFillMode)((NSNumber*)[aDecoder decodeObjectForKey:@"notesAutoFillMode"]).longValue;
        
        NSString* titleCustomAutoFill = [aDecoder decodeObjectForKey:@"titleCustomAutoFill"];
        NSString* usernameCustomAutoFill = [aDecoder decodeObjectForKey:@"usernameCustomAutoFill"];
        NSString* passwordCustomAutoFill = [aDecoder decodeObjectForKey:@"passwordCustomAutoFill"];
        NSString* emailCustomAutoFill = [aDecoder decodeObjectForKey:@"emailCustomAutoFill"];
        NSString* urlCustomAutoFill = [aDecoder decodeObjectForKey:@"urlCustomAutoFill"];
        NSString* notesCustomAutoFill = [aDecoder decodeObjectForKey:@"notesCustomAutoFill"];
        
        
        
        if ( titleCustomAutoFill ) {
            self.titleCustomAutoFill = titleCustomAutoFill;
        }
        
        if ( usernameCustomAutoFill ) {
            self.usernameCustomAutoFill = usernameCustomAutoFill;
        }
        
        if ( passwordCustomAutoFill ) {
            self.passwordCustomAutoFill = passwordCustomAutoFill;
        }
        
        if ( emailCustomAutoFill ) {
            self.emailCustomAutoFill = emailCustomAutoFill;
        }
        
        if ( urlCustomAutoFill ) {
            self.urlCustomAutoFill = urlCustomAutoFill;
        }
        
        if ( notesCustomAutoFill ) {
            self.notesCustomAutoFill = notesCustomAutoFill;
        }
    }
    
    return self;
}



- (NSString *)titleCustomAutoFill {
    return [SecretStore.sharedInstance getSecureString:kNewEntryDefaultsCustomTitle];
}

- (void)setTitleCustomAutoFill:(NSString *)titleCustomAutoFill {
    [SecretStore.sharedInstance setSecureString:titleCustomAutoFill forIdentifier:kNewEntryDefaultsCustomTitle];
}



- (NSString *)usernameCustomAutoFill {
    return [SecretStore.sharedInstance getSecureString:kNewEntryDefaultsCustomUsername];
}

- (void)setUsernameCustomAutoFill:(NSString *)usernameCustomAutoFill {
    [SecretStore.sharedInstance setSecureString:usernameCustomAutoFill forIdentifier:kNewEntryDefaultsCustomUsername];
}



- (NSString *)passwordCustomAutoFill {
    return [SecretStore.sharedInstance getSecureString:kNewEntryDefaultsCustomPassword];
}

- (void)setPasswordCustomAutoFill:(NSString *)passwordCustomAutoFill {
    [SecretStore.sharedInstance setSecureString:passwordCustomAutoFill forIdentifier:kNewEntryDefaultsCustomPassword];
}



- (NSString *)emailCustomAutoFill {
    return [SecretStore.sharedInstance getSecureString:kNewEntryDefaultsCustomEmail];
}

- (void)setEmailCustomAutoFill:(NSString *)emailCustomAutoFill {
    [SecretStore.sharedInstance setSecureString:emailCustomAutoFill forIdentifier:kNewEntryDefaultsCustomEmail];
}



- (NSString *)urlCustomAutoFill {
    return [SecretStore.sharedInstance getSecureString:kNewEntryDefaultsCustomUrl];
}

- (void)setUrlCustomAutoFill:(NSString *)urlCustomAutoFill {
    [SecretStore.sharedInstance setSecureString:urlCustomAutoFill forIdentifier:kNewEntryDefaultsCustomUrl];
}



- (NSString *)notesCustomAutoFill {
    return [SecretStore.sharedInstance getSecureString:kNewEntryDefaultsCustomNotes];
}

- (void)setNotesCustomAutoFill:(NSString *)notesCustomAutoFill {
    [SecretStore.sharedInstance setSecureString:notesCustomAutoFill forIdentifier:kNewEntryDefaultsCustomNotes];
}

@end
