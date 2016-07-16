//
//  AddSafeViewController.m
//  StrongBox
//
//  Created by Mark McGuill on 05/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "AddSafeViewController.h"
#import "core-model/SafeDatabase.h"
#import "GoogleDriveManager.h"
#import <DropboxSDK/DropboxSDK.h>
#import "MBProgressHUD.h"
#import "core-model/Utils.h"
#import "BSKeyboardControls.h"
#import "GTLDriveParentReference.h"

@interface AddSafeViewController () <DBRestClientDelegate, UITextFieldDelegate, UIScrollViewDelegate, BSKeyboardControlsDelegate>
@property (nonatomic, strong) BSKeyboardControls *keyboardControls;
@end

@implementation AddSafeViewController
{
    UIScrollView *_scroller;
}

-(void) viewDidLoad
{
    self.textPassword.delegate = self;
    self.textConfirmMasterPassword.delegate = self;
    self.textName.delegate = self;
    
    _scroller = [[UIScrollView alloc] initWithFrame:CGRectMake(0,0, self.view.bounds.size.width, self.view.bounds.size.height - self.navigationController.toolbar.bounds.size.height - self.navigationController.navigationBar.bounds.size.height)]; // self.view.bounds
    _scroller.delegate = self;
    _scroller.contentSize = self.viewInternal.frame.size;
    
    self.viewInternal.frame = self.view.bounds;
    
    [_scroller addSubview:self.viewInternal];
    [self.view addSubview:_scroller];
    
    [self registerForKeyboardNotifications];
    
    NSArray *fields = @[ self.textPassword, self.textConfirmMasterPassword,
                         self.textName];
    
    [self setKeyboardControls:[[BSKeyboardControls alloc] initWithFields:fields]];
    [self.keyboardControls setDelegate:self];

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
    
    int height = kbSize.height; // + self.keyboardControls.bounds.size.height + 40;
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, height, 0.0);
    _scroller.contentInset = contentInsets;
    _scroller.scrollIndicatorInsets = contentInsets;
    
//    // If active text field is hidden by keyboard, scroll it so it's visible
//    // Your app might not need or want this behavior.
//    CGRect aRect = self.view.frame;
//    aRect.size.height -= height;
//    if (!CGRectContainsPoint(aRect, _activeField.frame.origin) ) {
//        [_scroller scrollRectToVisible:_activeField.frame animated:YES];
//    }
}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    _scroller.contentInset = contentInsets;
    _scroller.scrollIndicatorInsets = contentInsets;
}

- (void)keyboardControlsDonePressed:(BSKeyboardControls *)keyboardControls
{
    [keyboardControls.activeField resignFirstResponder];
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    [self.keyboardControls setActiveField:textField];
}

-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.textConfirmMasterPassword.hidden = self.existing;
    self.textPassword.hidden = self.existing;
    self.labelConfirmMasterPassword.hidden = self.existing;
    self.labelMasterPassword.hidden = self.existing;
    
    self.title = self.existing ? @"Set Nickname" : @"Set Master Password";
    [self enableAppropriateControls];
}

-(void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if(!self.existing)
    {
        [self.textPassword becomeFirstResponder];
    }
    else
    {
        [self.textName becomeFirstResponder];
    }
}

- (IBAction)onTextFieldsChanged:(id)sender {
    [self enableAppropriateControls];
}

-(void) enableAppropriateControls
{
    self.buttonAddSafe.enabled = NO;
    [self.buttonAddSafe setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
    [self.buttonAddSafe setTitleColor:[UIColor grayColor] forState:UIControlStateHighlighted];
    
    if(!self.existing)
    {
        if(self.textPassword.text.length > 0)
        {
            //self.textConfirmMasterPassword.enabled = YES;
        
            if([self.textPassword.text isEqualToString:self.textConfirmMasterPassword.text])
            {
                //self.textName.enabled = YES;
                self.labelPasswordsDontMatch.hidden = NO;
                self.labelPasswordsDontMatch.textColor = [UIColor blueColor];
                self.labelPasswordsDontMatch.text = @"[Passwords Match]";
                
                if([self.safes isValidNickName:self.textName.text])
                {
                    self.buttonAddSafe.enabled = YES;
                    [self.buttonAddSafe setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
                    [self.buttonAddSafe setTitleColor:[UIColor blueColor] forState:UIControlStateHighlighted];
                }
            }
            else
            {
                //self.textName.enabled = NO;
                self.labelPasswordsDontMatch.hidden = NO;
                self.labelPasswordsDontMatch.textColor = [UIColor redColor];
                self.labelPasswordsDontMatch.text = @"* The passwords do not match";
            }
        }
        else
        {
            self.labelPasswordsDontMatch.hidden = YES;
            //self.textName.enabled = NO;
            //self.textConfirmMasterPassword.enabled = NO;
        }
    }
    else
    {
        self.labelPasswordsDontMatch.hidden = YES;
        //self.textName.enabled = YES;
        if([self.safes isValidNickName:self.textName.text])
        {
            self.buttonAddSafe.enabled = YES;
            [self.buttonAddSafe setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
            [self.buttonAddSafe setTitleColor:[UIColor blueColor] forState:UIControlStateHighlighted];
        }
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSData *)createBrandNewSafe:(NSString *)password
{
    SafeDatabase* newSafe = [[SafeDatabase alloc] initNewWithPassword:password];
    NSData* data = [newSafe getAsData];
    
    if(data == nil)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error Saving Safe"
                                                        message:@"There was a problem saving the safe."
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        
        return nil;
    }
    
    return data;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)buttonAddSafe:(id)sender
{
    NSString *nickName = [self.safes sanitizeSafeNickName:self.textName.text];
    
    // TODO: Auto indicate this in GUI -> instead of waiting for click
    
    if(![self.safes isValidNickName:nickName])
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Invalid Nick Name" message:@"This Nick Name may already exist in your safes, or be invalid. Please choose another one."
                                                       delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        
        return;
    }
    
    SafeMetaData *safe = [[SafeMetaData alloc] initWithNickName:nickName
                                                storageProvider:[self.safeStorageProvider getStorageId]];
    
    if(!self.existing) // New
    {
        [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        
        // We need to do this in the background or we get horrible stalls without the spinner
        
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void)
        {
            NSData *data = [self createBrandNewSafe:self.textPassword.text];

            // The Saving must be done on the main GUI thread!
            
            dispatch_async(dispatch_get_main_queue(), ^(void){
                [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
                
                [self saveNewSafe:safe data:data];
            });
        });
    }
    else
    {
        if(safe.storageProvider == kGoogleDrive)
        {
            GTLDriveFile* file = (GTLDriveFile*)self.fileOrFolderObject;
            safe.fileName = file.title;
            
            GTLDriveParentReference *parent = [file.parents objectAtIndex:0];
            safe.fileIdentifier = parent.identifier;
        }
        else
        {
            DBMetadata* file = (DBMetadata*)self.fileOrFolderObject;
            safe.fileName = file.filename;
            safe.fileIdentifier = file.path;
        }
        
        [self.safes add:safe];
        
        [self.navigationController popToRootViewControllerAnimated:YES];
    }
}

- (void)saveNewSafe:(SafeMetaData *)safe data:(NSData *)data
{
    NSString *desiredFilename = [NSString stringWithFormat:@"%@-strongbox.dat", safe.nickName];
    NSString *parentFolder = (NSString*)self.fileOrFolderObject;
    
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    
    [self.safeStorageProvider create:desiredFilename data:data parentReference:parentFolder viewController:self completionHandler:^(NSString *fileName, NSString *fileIdentifier, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^(void){
            [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
            
            if (error == nil)
            {
                safe.fileIdentifier = fileIdentifier;
                safe.fileName = fileName;
                
                [self.safes add:safe];
            }
            else
            {
                NSLog(@"An error occurred: %@", error);
                
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error Saving Safe" message:@"There was a problem saving the safe."
                                                               delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [alert show];
            }
            
            [self.navigationController popToRootViewControllerAnimated:YES];
        });
    }];
}

@end
