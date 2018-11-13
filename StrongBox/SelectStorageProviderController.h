//
//  SelectStorageProviderController.h
//  StrongBox
//
//  Created by Mark on 08/09/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AbstractPasswordDatabase.h"

@interface SelectStorageProviderController : UITableViewController

@property (nonatomic) BOOL existing;
@property (nonatomic) DatabaseFormat format;

@end
