//
//  AutoFillNewRecordSettings.m
//  Strongbox-iOS
//
//  Created by Mark on 04/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "AutoFillNewRecordSettings.h"

@implementation AutoFillNewRecordSettings

+ (instancetype)defaults {
    AutoFillNewRecordSettings *defaultInstance = [[AutoFillNewRecordSettings alloc] init];
        
    defaultInstance.titleAutoFillMode = kDefault;
    defaultInstance.titleCustomAutoFill = @"Custom Title Autofill Text";
    
    defaultInstance.usernameAutoFillMode = kMostUsed;
    defaultInstance.usernameCustomAutoFill = @"Custom Username Autofill Text";
    
    defaultInstance.passwordAutoFillMode = kGenerated;
    defaultInstance.passwordCustomAutoFill = @"Custom Password Autofill Text";
    
    defaultInstance.emailAutoFillMode = kMostUsed;
    defaultInstance.emailCustomAutoFill = @"Custom Email Autofill Text";
    
    defaultInstance.urlAutoFillMode = kNone;
    defaultInstance.urlCustomAutoFill = @"Custom URL Autofill Text";
    
    defaultInstance.notesAutoFillMode = kNone;
    defaultInstance.notesCustomAutoFill = @"Custom Notes Autofill Text";
    
    return defaultInstance;
}

- (void)encodeWithCoder:(NSCoder *)aCoder{
    [aCoder encodeObject:@(self.titleAutoFillMode) forKey:@"titleAutoFillMode"];
    [aCoder encodeObject:self.titleCustomAutoFill forKey:@"titleCustomAutoFill"];
    [aCoder encodeObject:@(self.usernameAutoFillMode) forKey:@"usernameAutoFillMode"];
    [aCoder encodeObject:self.usernameCustomAutoFill forKey:@"usernameCustomAutoFill"];
    [aCoder encodeObject:@(self.passwordAutoFillMode) forKey:@"passwordAutoFillMode"];
    [aCoder encodeObject:self.passwordCustomAutoFill forKey:@"passwordCustomAutoFill"];
    [aCoder encodeObject:@(self.emailAutoFillMode) forKey:@"emailAutoFillMode"];
    [aCoder encodeObject:self.emailCustomAutoFill forKey:@"emailCustomAutoFill"];
    [aCoder encodeObject:@(self.urlAutoFillMode) forKey:@"urlAutoFillMode"];
    [aCoder encodeObject:self.urlCustomAutoFill forKey:@"urlCustomAutoFill"];
    [aCoder encodeObject:@(self.notesAutoFillMode) forKey:@"notesAutoFillMode"];
    [aCoder encodeObject:self.notesCustomAutoFill forKey:@"notesCustomAutoFill"];
}

-(id)initWithCoder:(NSCoder *)aDecoder{
    if(self = [super init]){
        NSNumber* obj = [aDecoder decodeObjectForKey:@"titleAutoFillMode"];
        self.titleAutoFillMode = (AutoFillMode)obj.longValue;
        self.titleCustomAutoFill = [aDecoder decodeObjectForKey:@"titleCustomAutoFill"];
        self.usernameAutoFillMode = (AutoFillMode)((NSNumber*)[aDecoder decodeObjectForKey:@"usernameAutoFillMode"]).longValue;
        self.usernameCustomAutoFill = [aDecoder decodeObjectForKey:@"usernameCustomAutoFill"];
        self.passwordAutoFillMode = (AutoFillMode)((NSNumber*)[aDecoder decodeObjectForKey:@"passwordAutoFillMode"]).longValue;
        self.passwordCustomAutoFill = [aDecoder decodeObjectForKey:@"passwordCustomAutoFill"];
        self.emailAutoFillMode = (AutoFillMode)((NSNumber*)[aDecoder decodeObjectForKey:@"emailAutoFillMode"]).longValue;
        self.emailCustomAutoFill = [aDecoder decodeObjectForKey:@"emailCustomAutoFill"];
        self.urlAutoFillMode = (AutoFillMode)((NSNumber*)[aDecoder decodeObjectForKey:@"urlAutoFillMode"]).longValue;
        self.urlCustomAutoFill = [aDecoder decodeObjectForKey:@"urlCustomAutoFill"];
        self.notesAutoFillMode = (AutoFillMode)((NSNumber*)[aDecoder decodeObjectForKey:@"notesAutoFillMode"]).longValue;
        self.notesCustomAutoFill = [aDecoder decodeObjectForKey:@"notesCustomAutoFill"];
    }
    
    return self;
}

@end
