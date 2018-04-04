//
//  SafesMetaDataViewer.h
//  Macbox
//
//  Created by Mark on 04/04/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SafesMetaDataViewer : NSWindowController<NSTableViewDelegate, NSTableViewDataSource>

@property (weak) IBOutlet NSTableView *tableView;

@end
