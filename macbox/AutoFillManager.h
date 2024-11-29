//
//  AutoFillManager.h
//  Strongbox
//
//  Created by Mark on 01/04/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Model.h"
#import "QuickTypeAutoFillDisplayFormat.h"

NS_ASSUME_NONNULL_BEGIN

@interface AutoFillManager : NSObject 

+ (instancetype)sharedInstance;

@property (readonly) BOOL isOnForStrongbox;

- (void)updateAutoFillQuickTypeDatabase:(Model *)database clearFirst:(BOOL)clearFirst;

- (void)clearAutoFillQuickTypeDatabase;

- (void)refreshQuickTypeSuggestionForEntry:(Node*)node database:(Model*)database previousSuggestionText:(NSString* _Nullable)previousSuggestionText;

- (void)removeItemsFromQuickType:(const NSArray<Node*>*)items database:(Model*)database;

- (NSString*)getQuickTypeUserText:(Model*)database
                             node:(Node*)node
                  usedEmailAsUser:(BOOL*_Nullable)usedEmailAsUser
                         fieldKey:(NSString*_Nullable)fieldKey;

@end

NS_ASSUME_NONNULL_END
