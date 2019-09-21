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
- (void)setKey:(NSString*)key value:(NSString*)value editing:(BOOL)editing suggestionProvider:(SuggestionProvider _Nullable)suggestionProvider useEasyReadFont:(BOOL)useEasyReadFont;
- (void)setKey:(NSString *)key value:(NSString *)value editing:(BOOL)editing formatAsUrl:(BOOL)formatAsUrl suggestionProvider:(SuggestionProvider _Nullable)suggestionProvider useEasyReadFont:(BOOL)useEasyReadFont;

- (void)setKey:(NSString*)key value:(NSString*)value editing:(BOOL)editing selectAllOnEdit:(BOOL)selectAllOnEdit useEasyReadFont:(BOOL)useEasyReadFont;

@property (nonatomic, copy, nullable) void (^onEdited)(NSString* text);
@property (nonatomic, copy, nullable) SuggestionProvider suggestionProvider;

@property BOOL showUiValidationOnEmpty;

@property (nonatomic, copy) void (^onTap)(void);
@property (nonatomic, copy) void (^onDoubleTap)(void);

@end

NS_ASSUME_NONNULL_END
