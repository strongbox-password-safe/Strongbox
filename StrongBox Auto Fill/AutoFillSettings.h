//
//  AutoFillSettings.h
//  Strongbox
//
//  Created by Strongbox on 13/06/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AutoFillSettings : NSObject

+ (instancetype)sharedInstance;

@property BOOL autoFillExitedCleanly;
@property BOOL autoFillWroteCleanly;

@property BOOL haveWarnedAboutAutoFillCrash;
@property BOOL dontNotifyToSwitchToMainAppForSync;
@property BOOL storeAutoFillServiceIdentifiersInNotes;
@property BOOL useFullUrlAsURLSuggestion;
@property BOOL autoProceedOnSingleMatch;

@end

NS_ASSUME_NONNULL_END
