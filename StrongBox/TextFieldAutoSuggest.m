//
//  TextFieldAutoSuggest.m
//  StrongBox
//
//  Created by Mark on 03/06/2017.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "TextFieldAutoSuggest.h"

@interface TextFieldAutoSuggest () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) NSArray<NSString*> *suggestions;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, weak) UITextField *textField;
@property (nonatomic, weak) UIViewController *viewController;
@property (nonatomic, strong) SuggestionProvider suggestionProvider;

@end

@implementation TextFieldAutoSuggest

- (instancetype)initForTextField:(UITextField*)textField
                  viewController:(UIViewController*)viewController
             suggestionsProvider:(SuggestionProvider)suggestionsProvider
{
    if(self = [super init]) {
        self.maxVisibleSuggestions = 3;
        self.suggestions = [NSArray array];
        self.suggestionProvider = suggestionsProvider;
        
        [self initializeTableView];
        
        self.viewController = viewController;
        self.textField = textField;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(textChanged:)
                                                     name:UITextFieldTextDidChangeNotification
                                                   object:self.textField];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(endEditing:)
                                                     name:UITextFieldTextDidEndEditingNotification
                                                   object:self.textField];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(startEditing:)
                                                     name:UITextFieldTextDidBeginEditingNotification
                                                   object:self.textField];
    }
    
    return self;
}

- (void)initializeTableView
{
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    CALayer *layer = self.tableView.layer;
    [layer setMasksToBounds:YES];
    [layer setCornerRadius: 4.0];
    [layer setBorderWidth:1.0];
    [layer setBorderColor:[[UIColor colorWithWhite: 0.8 alpha: 1.0] CGColor]];
}

- (void)startEditing:(id)sender
{
    
    
    self.tableView.hidden = YES;
    [self.viewController.view addSubview:self.tableView];
}

- (void)endEditing:(id)sender
{
    
    
    self.tableView.hidden = YES;
    [self.tableView removeFromSuperview];
}

- (void)textChanged:(id)sender
{
    self.suggestions = self.suggestionProvider(self.textField.text);
    
    [self.tableView reloadData];
    
    CGRect rectWithinController;
    
    
    
    if(self.textField.superview != self.viewController.view) {
        rectWithinController = [self.textField.superview convertRect:self.textField.frame toView:self.viewController.view];
    }
    else
    {
        rectWithinController = self.textField.frame;
    }
    
    CGRect rowRect = [self.tableView rectForRowAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
    CGFloat height = (MIN(self.suggestions.count, self.maxVisibleSuggestions)) * rowRect.size.height;
    
    self.tableView.hidden = !(self.suggestions.count);
    
    
    
    self.tableView.frame = CGRectMake(rectWithinController.origin.x,
                                      rectWithinController.origin.y + rectWithinController.size.height,
                                      rectWithinController.size.width,
                                      height);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.suggestions.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"TextFieldAutoSuggestCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    NSString *suggestion = self.suggestions[indexPath.row];
    
    cell.textLabel.text = suggestion;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *suggestion = self.suggestions[(NSUInteger)indexPath.row];
    
    self.textField.text = suggestion;
    
    [self.textField resignFirstResponder];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UITextFieldTextDidChangeNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UITextFieldTextDidEndEditingNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UITextFieldTextDidBeginEditingNotification
                                                  object:nil];
}

@end
