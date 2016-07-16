//
//  FieldsViewTableViewController.m
//  StrongBox
//
//  Created by Mark McGuill on 12/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "RecordViewController.h"
#import "core-model/Field.h"
#import "AdvancedRecordViewController.h"
#import "MBProgressHUD.h"

@interface RecordViewController ()

@end

@implementation RecordViewController 
{
    UIBarButtonItem *navBack;
    UIScrollView *_scroller;
    NSMutableArray *_entryFields;
    
    UITableView *autocompleteTableView;
    UITextView *currentAutocompleteTextView;
    NSMutableArray *autocompletes;
}

- (void)setInitialTextFieldBordersAndColors
{
    self.textViewNotes.layer.borderWidth = 1.0f;
    self.textViewPassword.layer.borderWidth = 1.0f;
    self.textViewTitle.layer.borderWidth = 1.0f;
    self.textViewUrl.layer.borderWidth = 1.0f;
    self.textViewUsername.layer.borderWidth = 1.0f;
    
    self.textViewNotes.layer.cornerRadius = 5;
    self.textViewPassword.layer.cornerRadius = 5;
    self.textViewTitle.layer.cornerRadius = 5;
    self.textViewUrl.layer.cornerRadius = 5;
    self.textViewUsername.layer.cornerRadius = 5;
    
    
    self.textViewNotes.layer.borderColor = [[UIColor lightGrayColor] CGColor];
    self.textViewPassword.layer.borderColor = [[UIColor lightGrayColor] CGColor];
    self.textViewTitle.layer.borderColor = [[UIColor lightGrayColor] CGColor];
    self.textViewUrl.layer.borderColor = [[UIColor lightGrayColor] CGColor];
    self.textViewUsername.layer.borderColor = [[UIColor lightGrayColor] CGColor];
    
    self.textViewNotes.delegate = self;
    self.textViewPassword.delegate = self;
    self.textViewTitle.delegate = self;
    self.textViewUrl.delegate = self;
    self.textViewUsername.delegate = self;

    self.textViewTitle.textContainer.maximumNumberOfLines = 1;
    self.textViewTitle.textContainer.lineBreakMode = NSLineBreakByTruncatingTail;
    self.textViewUsername.textContainer.maximumNumberOfLines = 1;
    self.textViewUsername.textContainer.lineBreakMode = NSLineBreakByTruncatingTail;
    self.textViewPassword.textContainer.maximumNumberOfLines = 1;
    self.textViewPassword.textContainer.lineBreakMode = NSLineBreakByTruncatingTail;
    self.textViewUrl.textContainer.maximumNumberOfLines = 1;
    self.textViewUrl.textContainer.lineBreakMode = NSLineBreakByTruncatingTail;
}

- (void)setupAutocompleteForUsername
{
    // Setup Autocomplete
    
    autocompletes = [[NSMutableArray alloc] init];
    autocompleteTableView = [[UITableView alloc] initWithFrame:
                             CGRectMake(0, 0, 0, 0) style:UITableViewStylePlain];
    
    autocompleteTableView.delegate = self;
    autocompleteTableView.dataSource = self;
    autocompleteTableView.hidden = YES;
    autocompleteTableView.scrollEnabled = YES;
    
    
    CALayer *layer = autocompleteTableView.layer;
    [layer setMasksToBounds:YES];
    [layer setCornerRadius: 4.0];
    [layer setBorderWidth:1.0];
    [layer setBorderColor:[[UIColor colorWithWhite:0.8f alpha:1.0f] CGColor]];
    
    [self.view addSubview:autocompleteTableView];
}

-(void)viewDidLoad
{
    [self setInitialTextFieldBordersAndColors];

    [self.buttonAdvanced setEnabled:(self.record != nil)];
    self.navigationItem.rightBarButtonItem = self.viewModel.isUsingOfflineCache ? nil : self.editButtonItem;

    // Setup Scrollview...
    
    _scroller = [[UIScrollView alloc] initWithFrame:CGRectMake(0,0, self.view.bounds.size.width, self.view.bounds.size.height - self.navigationController.toolbar.bounds.size.height - self.navigationController.navigationBar.bounds.size.height)];
    _scroller.delegate = self;
    _scroller.contentSize = self.viewInternal.frame.size;
    [_scroller addSubview:self.viewInternal];
    
    [self.view addSubview:_scroller];
    
    // Setup Keyboard Focus
    
    NSArray *fields = @[ self.textViewTitle, self.textViewUsername, self.textViewPassword, self.textViewUrl, self.textViewNotes];
    
    [self setKeyboardControls:[[BSKeyboardControls alloc] initWithFields:fields]];
    [self.keyboardControls setDelegate:self];
    
    [self registerForKeyboardNotifications];
    
    //
    
    [self reloadFieldsFromRecord];
    
    [self setupAutocompleteForUsername];
    
    // New or existing...
    
    [self setEditing:(self.record == nil) animated:YES];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.navigationController.navigationBar.hidden = NO;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Auto complete stuff

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return autocompletes.count;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle: UITableViewCellStyleDefault reuseIdentifier:@"AutocompleteCell"];

    cell.textLabel.text = [autocompletes objectAtIndex:indexPath.row];
    
    return cell;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return self.textViewPassword.frame.size.height;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    currentAutocompleteTextView.text = [autocompletes objectAtIndex:indexPath.row];
    
    autocompleteTableView.hidden = YES;
}

-(BOOL)textViewHasAutocomplete:(UITextView*)textView
{
    return (textView == self.textViewUsername || textView == self.textViewPassword);
}

-(void)textViewDidBeginEditing:(UITextView *)textView
{
    [self.keyboardControls setActiveField:textView];
    
    if(textView.text.length != 0 && [self textViewHasAutocomplete:textView])
    {
        currentAutocompleteTextView = textView;
        autocompleteTableView.hidden = NO;
        
        NSString *substring = [NSString stringWithString:currentAutocompleteTextView.text];
        
        [self displayAutocompleteEntriesWithSubstring:substring isPassword:(textView == self.textViewPassword)];
    }

    if(textView == self.textViewUsername &&
       (self.record == nil) &&
       self.textViewUsername.text.length == 0)
    {
        self.textViewUsername.text = [self.viewModel getMostPopularUsername];
        dispatch_async(dispatch_get_main_queue(), ^{
            [textView selectAll:nil];
        });
    }
    
    if(textView == self.textViewPassword &&
       (self.record == nil) &&
       self.textViewPassword.text.length == 0)
    {
        self.textViewPassword.text = [self.viewModel getMostPopularPassword];
        dispatch_async(dispatch_get_main_queue(), ^{
            [textView selectAll:nil];
        });
    }
}

-(void)textViewDidEndEditing:(UITextView *)textView
{
    if(textView == self.textViewUsername)
    {
        currentAutocompleteTextView = nil;
        autocompleteTableView.hidden = YES;
    }
    else if(textView == self.textViewPassword)
    {
        currentAutocompleteTextView = nil;
        autocompleteTableView.hidden = YES;
    }
}

-(BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    if([self textViewHasAutocomplete:textView])
    {
        autocompleteTableView.hidden = NO;
    
        currentAutocompleteTextView = textView;
        
        NSString *substring = [NSString stringWithString:currentAutocompleteTextView.text];
        substring = [substring
                     stringByReplacingCharactersInRange:range withString:text];
        
        [self displayAutocompleteEntriesWithSubstring:substring isPassword:(textView == self.textViewPassword)];
    }
    
    // Tabbing around stuff
    
    BOOL shouldChangeText = YES;
    
    if ([text isEqualToString:@"\t"] || [text isEqualToString:@"\n"])
    {
        // Find the next entry field
        BOOL isLastField = YES;
        for (UIView *view in [self entryFields])
        {
            if (view.tag == (textView.tag + 1))
            {
                [view becomeFirstResponder];
                isLastField = NO;
                break;
            }
        }
        if (!isLastField)
        {
            shouldChangeText = NO;
        }
    }
    
    return shouldChangeText;
}

- (void)displayAutocompleteEntriesWithSubstring:(NSString *)substring isPassword:(BOOL)isPassword {
    
    // Put anything that starts with this substring into the autocompleteUrls array
    // The items in this array is what will show up in the table view
    
    [autocompletes removeAllObjects];
    
    NSArray *possibles = isPassword ?
                              [[self.viewModel getAllExistingPasswords] allObjects]
                            : [[self.viewModel getAllExistingUserNames] allObjects];
    
    if(substring.length == 0)
    {
        [autocompletes addObjectsFromArray:possibles];
    }
    else
    {
        for(NSString *curString in possibles)
        {
            NSRange substringRange = [curString rangeOfString:substring];
       
            if (substringRange.location == 0)
            {
                [autocompletes addObject:curString];
            }
        }
    }

    // Calculate Height
    
    const NSUInteger maxAutocompleteRows = 3;
    CGFloat height = self.textViewPassword.frame.size.height;
    height *= MIN(autocompletes.count, maxAutocompleteRows);
    
    if(autocompletes.count > maxAutocompleteRows)
    {
        height += (self.textViewPassword.frame.size.height/2);
    }
    
    // Adjust Frame / Position
    
    CGRect rcTextView = [currentAutocompleteTextView frame];
    CGRect tableFrame = CGRectMake(rcTextView.origin.x, rcTextView.origin.y + rcTextView.size.height + 1, rcTextView.size.width, height);
    
    autocompleteTableView.frame = tableFrame;
    
    [autocompleteTableView setNeedsDisplay];
    [autocompleteTableView reloadData];
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Keyboard stuff

- (void)keyboardControlsDonePressed:(BSKeyboardControls *)keyboardControls
{
    [keyboardControls.activeField resignFirstResponder];
}

- (void)registerForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];
}


// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWasShown:(NSNotification*)aNotification
{
    NSDictionary* info = [aNotification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    int height = kbSize.height; // + self.keyboardControls.bounds.size.height;
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, height, 0.0);
    _scroller.contentInset = contentInsets;
    _scroller.scrollIndicatorInsets = contentInsets;
}

- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    _scroller.contentInset = contentInsets;
    _scroller.scrollIndicatorInsets = contentInsets;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

-(void)textViewDidChange:(UITextView *)textView
{
    self.editButtonItem.enabled = [self uiIsDirty];
}

/*
 Returns an array of all data entry fields in the view.
 Fields are ordered by tag, and only fields with tag > 0 are included.
 Returned fields are guaranteed to be a subclass of UIResponder.
 */
- (NSArray *)entryFields
{
    if (!_entryFields)
    {
        _entryFields = [[NSMutableArray alloc] init];
        NSInteger tag = 1;
        UIView *aView;
        while ((aView = [self.view viewWithTag:tag]))
        {
            if (aView && [[aView class] isSubclassOfClass:[UIResponder class]])
            {
                [_entryFields addObject:aView];
            }
            tag++;
        }
    }
    
    return _entryFields;
}

-(BOOL)uiIsDirty
{
    return !([self.textViewNotes.text isEqualToString:self.record.notes]
             &&   [trim(self.textViewPassword.text) isEqualToString:self.record.password]
             &&   [trim(self.textViewTitle.text) isEqualToString:self.record.title]
             &&   [trim(self.textViewUrl.text) isEqualToString:self.record.url]
             &&   [trim(self.textViewUsername.text) isEqualToString:self.record.username]);
}

NSString* trim(NSString* string)
{
    return [string stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceCharacterSet]];
}

- (void)setEditing:(BOOL)flag animated:(BOOL)animated
{
    [super setEditing:flag animated:animated];
    
    if (flag == YES){
        navBack = self.navigationItem.leftBarButtonItem;
        self.editButtonItem.enabled = NO;
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(onCancelBarButton)];
        self.buttonAdvanced.enabled = NO;
    }
    else {
        if([self uiIsDirty]) // Any changes? Change the record and save the safe
        {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Save changes?"  message:@"Are you sure you want to save your changes?" delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
            alertView.tag = 1;
            // Confirm
            [alertView show];
        }
        else
        {
            self.buttonAdvanced.enabled = (self.record != nil);
            self.navigationItem.leftBarButtonItem = navBack;
            self.editButtonItem.enabled = YES;
            navBack = nil;
        }
    }
    
    [self updateFieldsForEditable];
    
    if(flag == YES)
    {
        [self.textViewTitle becomeFirstResponder];
    }
}

- (void)saveChangesToSafe
{
    BOOL recordNeedsToBeAddedToSafe = (self.record == nil);
    
    if(recordNeedsToBeAddedToSafe)
    {
        self.record =[[Record alloc] init];
        self.record.group = self.currentGroup;
        self.record.created = [[NSDate alloc] init];
        [self.viewModel.safe addRecord:self.record];
    }
    
    // Access/Modification Times
    
    self.record.accessed = [[NSDate alloc] init];
    self.record.modified = [[NSDate alloc] init];
    if(![self.record.password isEqualToString:self.textViewPassword.text])
    {
        self.record.passwordModified = [[NSDate alloc] init];
    }
    
    // Text Fields
    
    self.record.notes = self.textViewNotes.text;
    self.record.password = trim(self.textViewPassword.text);
    self.record.title = trim(self.textViewTitle.text);
    self.record.url = trim(self.textViewUrl.text);
    self.record.username = trim(self.textViewUsername.text);
    
    // Save and Restore UI
    
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    
    [self.viewModel update:self completionHandler:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^(void){
            [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
            
            self.navigationItem.leftBarButtonItem = navBack;
            self.editButtonItem.enabled = YES;
            navBack = nil;
            
            if(error != nil)
            {
                NSLog(@"%@", error);
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Problem Saving"  message:@"There was a problem saving the safe." delegate:nil cancelButtonTitle:@"Cancel" otherButtonTitles: nil  ];
                [alertView show];
            }
            else
            {
                [self reloadFieldsFromRecord];
                [self.navigationController popViewControllerAnimated:YES];
            }
        });
    }];
}

-(void)onCancelBarButton
{
    if(self.record == nil)
    {
        // Back to safe view if we just cancelled out of a new record
        [self.navigationController popViewControllerAnimated:YES];
    }
    else
    {
        [self reloadFieldsFromRecord];
        
        [self setEditing:NO animated:YES];
    }
}

-(void)updateFieldsForEditable
{
    self.textViewNotes.editable = [self isEditing];
    self.textViewPassword.editable = [self isEditing];
    self.textViewTitle.editable = [self isEditing];
    self.textViewUrl.editable = [self isEditing];
    self.textViewUsername.editable = [self isEditing];
    
    self.textViewNotes.textColor = [self isEditing] ? [UIColor blackColor] : [UIColor grayColor];
    self.textViewPassword.textColor = [self isEditing] ? [UIColor blackColor] : [UIColor grayColor];
    self.textViewTitle.textColor = [self isEditing] ? [UIColor blackColor] : [UIColor grayColor];
    self.textViewUrl.textColor = [self isEditing] ? [UIColor blackColor] : [UIColor grayColor];
    self.textViewUsername.textColor = [self isEditing] ? [UIColor blackColor] : [UIColor grayColor];
    
    self.textViewNotes.layer.borderColor = [self isEditing] ? [[UIColor darkGrayColor] CGColor] : [[UIColor lightGrayColor] CGColor];
    self.textViewPassword.layer.borderColor = [self isEditing] ? [[UIColor darkGrayColor] CGColor] : [[UIColor lightGrayColor] CGColor];
    self.textViewTitle.layer.borderColor = [self isEditing] ? [[UIColor darkGrayColor] CGColor] : [[UIColor lightGrayColor] CGColor];
    self.textViewUrl.layer.borderColor = [self isEditing] ? [[UIColor darkGrayColor] CGColor] : [[UIColor lightGrayColor] CGColor];
    self.textViewUsername.layer.borderColor = [self isEditing] ? [[UIColor darkGrayColor] CGColor] : [[UIColor lightGrayColor] CGColor];
    

    UIImage *btnImage = [UIImage imageNamed:self.isEditing ? @"arrow_circle_left_64" : @"copy_64"];
    
    [self.buttonGeneratePassword setImage:btnImage forState:UIControlStateNormal];
    [self.buttonCopyUsername setEnabled:!self.isEditing];
    [self.buttonCopyUrl setEnabled:!self.isEditing];
    [self.buttonCopyNotes setEnabled:!self.isEditing];
}

- (void)reloadFieldsFromRecord
{
    if(self.record)
    {
        self.textViewPassword.text = self.record.password;
        self.textViewTitle.text = self.record.title;
        self.textViewUrl.text = self.record.url;
        self.textViewUsername.text = self.record.username;
        self.textViewNotes.text = self.record.notes;
        
        self.labelCreated.text = [self formatDate:self.record.created];
        self.labelAccessed.text = [self formatDate:self.record.accessed];
        self.labelModified.text = [self formatDate:self.record.modified];
        self.labelPasswordModified.text = [self formatDate:self.record.passwordModified];
        
        self.toolbarButtonDelete.enabled = !self.viewModel.isUsingOfflineCache;
        self.buttonAdvanced.enabled = YES;
    }
    else
    {
        self.textViewPassword.text = @"";
        self.textViewTitle.text = @"";
        self.textViewUrl.text = @"";
        self.textViewUsername.text = @"";
        self.textViewNotes.text = @"";
        
        self.labelCreated.text = @"";
        self.labelAccessed.text = @"";
        self.labelModified.text = @"";
        self.labelPasswordModified.text = @"";
        
        self.toolbarButtonDelete.enabled = NO;
        self.buttonAdvanced.enabled = NO;
    }
        
    self.navigationItem.title = [NSString stringWithFormat:@"%@%@", self.record ? self.record.title : @"<Untitled>", self.viewModel.isUsingOfflineCache ? @" [Offline]" : @""];
}

-(NSString*)formatDate:(NSDate*)date
{
    if(!date)
    {
        return @"[Unknown]";
    }
    NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    
    [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
    [dateFormatter setLocale:[NSLocale currentLocale]];
    
    NSString *dateString = [dateFormatter stringFromDate:date];
    
    return dateString;
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    AdvancedRecordViewController* vc = [segue destinationViewController];

    vc.record = self.record;
}

- (IBAction)onDeleteRecord:(id)sender
{
    if(self.record != nil)
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Are you sure?"  message:@"Are you sure you want to delete this record?" delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
        
        alertView.tag = 2;
        
        // Confirm
        [alertView show];
    }
}

- (IBAction)onGeneratePassword:(id)sender
{
    if([self isEditing])
    {
        self.textViewPassword.text = [self.viewModel generatePassword];

        self.editButtonItem.enabled = [self uiIsDirty];
    }
    else if(self.record)
    {
        if([self.record.password length] == 0){
            return;
        }
        
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = self.record.password;
        
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.navigationController.view animated:YES];
        
        // Configure for text only and offset down
        hud.mode = MBProgressHUDModeText;
        hud.labelText = @"Password Copied";
        hud.margin = 10.0f;
        hud.yOffset = (-self.view.frame.size.height / 2) + self.textViewPassword.frame.origin.y - 30; // Slightly above users touch
        hud.removeFromSuperViewOnHide = YES;
        hud.userInteractionEnabled = NO;
        
        [hud hide:YES afterDelay:3];
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(alertView.tag == 1) // Save Changes
    {
        if (buttonIndex == 1)
        {
                [self saveChangesToSafe];
        }
        else
        {
            // No  => revert fields
            [self reloadFieldsFromRecord];
            
            self.buttonAdvanced.enabled = (self.record != nil);
            self.navigationItem.leftBarButtonItem = navBack;
            self.editButtonItem.enabled = YES;
            navBack = nil;
            
            if(self.record == nil)
            {
                [self.navigationController popViewControllerAnimated:YES];
            }
        }
    }
    else if(alertView.tag == 2) // Delete Record
    {
        if (buttonIndex == 1 && self.record != nil)
        {
            NSLog(@"Delete!");
            
            [self.viewModel.safe deleteRecord: self.record];

            [MBProgressHUD showHUDAddedTo:self.view animated:YES];
            
            [self.viewModel update:self completionHandler:^(NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^(void){
                    [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
                        
                    if(error != nil)
                    {
                        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Problem Saving"  message:@"There was a problem saving changes to the safe." delegate:nil cancelButtonTitle:@"Cancel" otherButtonTitles: nil  ];
                        [alertView show];
                    }
                    else
                    {
                        [self.navigationController popViewControllerAnimated:YES];
                    }
                });
            }];
        }
    }
}

-(void)viewWillDisappear:(BOOL)animated
{
    // Set Accessed Time
    
    if(self.record)
    {
        // MMcG: RO Mode -> Don't update this, it's noise. Shapiro also recommended not to do this
        
        //self.record.accessed = [[NSDate alloc] init];
        //[self.viewModel save:self completionHandler:^(BOOL success, NSError *error) { }];
    }
}

- (IBAction)onCopyNotes:(id)sender
{
    if([self.record.notes length] == 0){
        return;
    }
    
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = self.record.notes;
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.navigationController.view animated:YES];
    
    // Configure for text only and offset down
    hud.mode = MBProgressHUDModeText;
    hud.labelText = @"Notes Copied";
    hud.margin = 10.0f;
    hud.yOffset = (-self.view.frame.size.height / 2) + self.textViewNotes.frame.origin.y - 30; // Slightly above users touch
    hud.removeFromSuperViewOnHide = YES;
    hud.userInteractionEnabled = NO;
    
    [hud hide:YES afterDelay:3];
}

- (IBAction)onCopyUrl:(id)sender {
    if([self.record.url length] == 0){
        return;
    }
    
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = self.record.url;
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.navigationController.view animated:YES];
    
    // Configure for text only and offset down
    hud.mode = MBProgressHUDModeText;
    hud.labelText = @"URL Copied";
    hud.margin = 10.0f;
    hud.yOffset = (-self.view.frame.size.height / 2) + self.textViewUrl.frame.origin.y - 30; // Slightly above users touch
    hud.removeFromSuperViewOnHide = YES;
    hud.userInteractionEnabled = NO;
    
    [hud hide:YES afterDelay:3];
}

- (IBAction)onCopyPasswordAndLaunchUrl:(id)sender
{
    if([self.record.url length] == 0){
        return;
    }
    
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = self.record.password;
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.navigationController.view animated:YES];
    
    // Configure for text only and offset down
    hud.mode = MBProgressHUDModeText;
    hud.labelText = @"Password Copied... Launching URL...";
    hud.margin = 10.0f;
    hud.yOffset = (-self.view.frame.size.height / 2) + self.textViewUrl.frame.origin.y - 30; // Slightly above users touch
    hud.removeFromSuperViewOnHide = YES;
    hud.userInteractionEnabled = NO;
    
    [hud hide:YES afterDelay:3];
    
    NSString* urlString = self.record.url;
    
    if (![urlString.lowercaseString hasPrefix:@"http://"] &&
        ![urlString.lowercaseString hasPrefix:@"https://"] ) {
        urlString = [NSString stringWithFormat:@"http://%@", urlString];
    }
    
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString]];
}

- (IBAction)onCopyUsername:(id)sender
{
    if([self.record.username length] == 0){
        return;
    }
    
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = self.record.username;
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.navigationController.view animated:YES];
    
    // Configure for text only and offset down
    hud.mode = MBProgressHUDModeText;
    hud.labelText = @"Username Copied";
    hud.margin = 10.0f;
    hud.yOffset = (-self.view.frame.size.height / 2) + self.textViewUsername.frame.origin.y - 30; // Slightly above users touch
    hud.removeFromSuperViewOnHide = YES;
    hud.userInteractionEnabled = NO;
    
    [hud hide:YES afterDelay:3];
}
@end
