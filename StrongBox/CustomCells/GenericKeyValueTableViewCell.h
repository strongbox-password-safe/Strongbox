//
//  GenericKeyValueTableViewCell.h
//  test-new-ui
//
//  Created by Mark on 18/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AutoCompleteTextField.h"

NS_ASSUME_NONNULL_BEGIN

@interface GenericKeyValueTableViewCell : UITableViewCell

- (void)setKey:(NSString*)key value:(NSString*)value editing:(BOOL)editing useEasyReadFont:(BOOL)useEasyReadFont;

- (void)setKey:(NSString*)key value:(NSString*)value editing:(BOOL)editing useEasyReadFont:(BOOL)useEasyReadFont rightButtonImage:(UIImage*_Nullable)rightButtonImage suggestionProvider:(SuggestionProvider _Nullable)suggestionProvider;

- (void)setKey:(NSString *)key value:(NSString *)value editing:(BOOL)editing useEasyReadFont:(BOOL)useEasyReadFont formatAsUrl:(BOOL)formatAsUrl rightButtonImage:(UIImage*_Nullable)rightButtonImage suggestionProvider:(SuggestionProvider _Nullable)suggestionProvider;

- (void)setConfidentialKey:(NSString*)key value:(NSString*)value concealed:(BOOL)concealed colorize:(BOOL)colorize audit:(NSString*_Nullable)audit;

- (void)setForUrlOrCustomFieldUrl:(NSString*)key value:(NSString*)value formatAsUrl:(BOOL)formatAsUrl rightButtonImage:(UIImage*)rightButtonImage useEasyReadFont:(BOOL)useEasyReadFont;

- (void)pokeValue:(NSString *)value;

@property (nonatomic, copy, nullable) void (^onEdited)(NSString* text);
@property (nonatomic, copy, nullable) SuggestionProvider suggestionProvider;

@property (nonatomic, copy, nullable) void (^onRightButton)(void);

@property (nonatomic, copy, nullable) void (^onAuditTap)(void);

@property BOOL showUiValidationOnEmpty;
@property BOOL isConcealed;

@end

NS_ASSUME_NONNULL_END
