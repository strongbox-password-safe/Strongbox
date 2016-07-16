//
//  AddSafeViewController.h
//  StrongBox
//
//  Created by Mark McGuill on 05/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SafeMetaData.h"
#import "SafeStorageProvider.h"
#import "SafesCollection.h"

@interface AddSafeViewController : UIViewController 
- (IBAction)buttonAddSafe:(id)sender;

@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet UITextField *textName;
@property (weak, nonatomic) IBOutlet UITextField *textPassword;
@property (weak, nonatomic) IBOutlet UITextField *textConfirmMasterPassword;
@property (weak, nonatomic) IBOutlet UILabel *labelPasswordsDontMatch;
@property (weak, nonatomic) IBOutlet UIView *viewInternal;
@property (weak, nonatomic) IBOutlet UIScrollView *scroll;

@property (weak, nonatomic) IBOutlet UILabel *labelMasterPassword;
@property (weak, nonatomic) IBOutlet UILabel *labelConfirmMasterPassword;
@property (weak, nonatomic) IBOutlet UIButton *buttonAddSafe;

- (IBAction)onTextFieldsChanged:(id)sender;

@property (nonatomic) BOOL existing;
@property (nonatomic) NSObject* fileOrFolderObject;
@property (nonatomic) id<SafeStorageProvider> safeStorageProvider;
@property (nonatomic) SafesCollection *safes;

@end
