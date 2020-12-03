//
//  SafesMetaDataViewer.h
//  Macbox
//
//  Created by Mark on 04/04/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern NSString* const kDatabasesListViewForceRefreshNotification;

@interface DatabasesManagerView : NSWindowController

+ (void)show:(BOOL)debug;

@end
