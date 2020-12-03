//
//  AutoFillSettings.m
//  Strongbox
//
//  Created by Strongbox on 13/06/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "AutoFillSettings.h"

static NSString* const kAutoFillExitedCleanly = @"autoFillExitedCleanly";
static NSString* const kAutoFillWroteCleanly = @"autoFillWroteCleanly";

static NSString* const kHaveWarnedAboutAutoFillCrash = @"haveWarnedAboutAutoFillCrash";
static NSString* const KDontNotifyToSwitchToMainAppForSync = @"dontNotifyToSwitchToMainAppForSync";
static NSString* const kStoreAutoFillServiceIdentifiersInNotes = @"storeAutoFillServiceIdentifiersInNotes";
static NSString* const kUseFullUrlAsURLSuggestion = @"useFullUrlAsURLSuggestion";
static NSString* const kAutoProceedOnSingleMatch = @"autoProceedOnSingleMatch";

@implementation AutoFillSettings

+ (instancetype)sharedInstance {
    static AutoFillSettings *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[AutoFillSettings alloc] init];
    });
    
    return sharedInstance;
}



- (BOOL)autoFillWroteCleanly {
    return [self getBool:kAutoFillWroteCleanly fallback:YES]; 
}

- (void)setAutoFillWroteCleanly:(BOOL)autoFillWroteCleanly {
    [self setBool:kAutoFillWroteCleanly value:autoFillWroteCleanly];
}

- (BOOL)useFullUrlAsURLSuggestion {
    return [self getBool:kUseFullUrlAsURLSuggestion];
}

- (void)setUseFullUrlAsURLSuggestion:(BOOL)useFullUrlAsURLSuggestion {
    [self setBool:kUseFullUrlAsURLSuggestion value:useFullUrlAsURLSuggestion];
}

- (BOOL)autoProceedOnSingleMatch {
    return [self getBool:kAutoProceedOnSingleMatch];
}

- (void)setAutoProceedOnSingleMatch:(BOOL)autoProceedOnSingleMatch {
    return [self setBool:kAutoProceedOnSingleMatch value:autoProceedOnSingleMatch];
}

- (BOOL)storeAutoFillServiceIdentifiersInNotes {
    return [self getBool:kStoreAutoFillServiceIdentifiersInNotes];
}

- (void)setStoreAutoFillServiceIdentifiersInNotes:(BOOL)storeAutoFillServiceIdentifiersInNotes {
    [self setBool:kStoreAutoFillServiceIdentifiersInNotes value:storeAutoFillServiceIdentifiersInNotes];
}

- (BOOL)autoFillExitedCleanly {
    return [self getBool:kAutoFillExitedCleanly fallback:YES];
}

- (void)setAutoFillExitedCleanly:(BOOL)autoFillExitedCleanly {
    return [self setBool:kAutoFillExitedCleanly value:autoFillExitedCleanly];
}

- (BOOL)haveWarnedAboutAutoFillCrash {
    return [self getBool:kHaveWarnedAboutAutoFillCrash];
}

- (void)setHaveWarnedAboutAutoFillCrash:(BOOL)haveWarnedAboutAutoFillCrash {
    [self setBool:kHaveWarnedAboutAutoFillCrash value:haveWarnedAboutAutoFillCrash];
}

- (BOOL)dontNotifyToSwitchToMainAppForSync {
    return [self getBool:KDontNotifyToSwitchToMainAppForSync];
}

- (void)setDontNotifyToSwitchToMainAppForSync:(BOOL)dontNotifyToSwitchToMainAppForSync {
    [self setBool:KDontNotifyToSwitchToMainAppForSync value:dontNotifyToSwitchToMainAppForSync];
}



- (NSUserDefaults*)getDefaults {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    
    if(defaults == nil) {
        NSLog(@"ERROR: Could not get AutoFill NSUserDefaults");
    }
    
    return defaults;
}



- (NSString*)getString:(NSString*)key {
    return [self getString:key fallback:nil];
}

- (NSString*)getString:(NSString*)key fallback:(NSString*)fallback {
    NSString* obj = [[self getDefaults] objectForKey:key];
    return obj != nil ? obj : fallback;
}

- (void)setString:(NSString*)key value:(NSString*)value {
    [[self getDefaults] setObject:value forKey:key];
    [[self getDefaults] synchronize];
}

- (BOOL)getBool:(NSString*)key {
    return [self getBool:key fallback:NO];
}

- (BOOL)getBool:(NSString*)key fallback:(BOOL)fallback {
    NSNumber* obj = [[self getDefaults] objectForKey:key];
    return obj != nil ? obj.boolValue : fallback;
}

- (void)setBool:(NSString*)key value:(BOOL)value {
    [[self getDefaults] setBool:value forKey:key];
    [[self getDefaults] synchronize];
}

- (NSInteger)getInteger:(NSString*)key {
    return [[self getDefaults] integerForKey:key];
}

- (NSInteger)getInteger:(NSString*)key fallback:(NSInteger)fallback {
    NSNumber* obj = [[self getDefaults] objectForKey:key];
    return obj != nil ? obj.integerValue : fallback;
}

- (void)setInteger:(NSString*)key value:(NSInteger)value {
    [[self getDefaults] setInteger:value forKey:key];
    [[self getDefaults] synchronize];
}

@end
