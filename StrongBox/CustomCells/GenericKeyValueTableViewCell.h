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

- (void)setKey:(NSString*)key value:(NSString*)value editing:(BOOL)editing suggestionProvider:(SuggestionProvider _Nullable)suggestionProvider useEasyReadFont:(BOOL)useEasyReadFont showGenerateButton:(BOOL)showGenerateButton;

- (void)setKey:(NSString *)key value:(NSString *)value editing:(BOOL)editing formatAsUrl:(BOOL)formatAsUrl suggestionProvider:(SuggestionProvider _Nullable)suggestionProvider useEasyReadFont:(BOOL)useEasyReadFont;

- (void)setKey:(NSString*)key value:(NSString*)value editing:(BOOL)editing selectAllOnEdit:(BOOL)selectAllOnEdit useEasyReadFont:(BOOL)useEasyReadFont;

- (void)setConfidentialKey:(NSString*)key value:(NSString*)value concealed:(BOOL)concealed colorize:(BOOL)colorize audit:(NSString*_Nullable)audit;

- (void)pokeValue:(NSString *)value;

@property (nonatomic, copy, nullable) void (^onEdited)(NSString* text);
@property (nonatomic, copy, nullable) SuggestionProvider suggestionProvider;

@property (nonatomic, copy, nullable) void (^onTap)(void);
@property (nonatomic, copy, nullable) void (^onDoubleTap)(void);
@property (nonatomic, copy, nullable) void (^onRightButton)(void);
@property (nonatomic, copy, nullable) void (^onGenerate)(void);

@property BOOL showUiValidationOnEmpty;
@property BOOL isConcealed;

@end

NS_ASSUME_NONNULL_END
