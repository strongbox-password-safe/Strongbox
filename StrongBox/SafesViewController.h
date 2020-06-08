//
//  SafesViewController.h
//  StrongBox
//
//  Created by Mark McGuill on 03/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SafesViewController : UITableViewController

- (void)enqueueImport:(NSURL *)url canOpenInPlace:(BOOL)canOpenInPlace;

@end
