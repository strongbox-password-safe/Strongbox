//
//  WindowController.h
//  MacBox
//
//  Created by Mark on 07/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Node.h"

NS_ASSUME_NONNULL_BEGIN

@interface WindowController : NSWindowController

- (void)updateContentView;
- (BOOL)placeItemsOnPasteboard:(NSPasteboard*)pasteboard items:(NSArray<Node*>*)items;
- (NSUInteger)pasteItemsFromPasteboard:(NSPasteboard*)pasteboard
                       destinationItem:(Node*)destinationItem
                              internal:(BOOL)internal
                                 clear:(BOOL)clear;



- (IBAction)onCopyPassword:(id _Nullable)sender;
- (IBAction)onDelete:(id _Nullable)sender;

- (Node*_Nullable)getSingleSelectedItem; 

@end

NS_ASSUME_NONNULL_END
