//
//  AttachmentItem.m
//  Strongbox
//
//  Created by Mark on 15/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "AttachmentItem.h"

@interface AttachmentItem ()

@end

@implementation AttachmentItem

+ (NSSet *)keyPathsForValuesAffectingTextColor {
    return [NSSet setWithObjects:@"selected", nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.wantsLayer = YES;
}

- (void) viewDidAppear
{
    
    [self updateBackgroundColorForSelectionState:self.isSelected];
}

- (void)updateBackgroundColorForSelectionState:(BOOL)flag
{
    if (flag)
    {
        self.view.layer.backgroundColor = [[NSColor alternateSelectedControlColor] CGColor];
    }
    else
    {
        self.view.layer.backgroundColor = [[NSColor clearColor] CGColor];
    }
}

- (void)setSelected:(BOOL)flag
{
    [super setSelected:flag];
    [self updateBackgroundColorForSelectionState:flag];
}

- (NSColor*) textColor
{
    return self.selected ? [NSColor selectedTextColor] : [NSColor textColor];
}

- (void) rightMouseDown:(NSEvent*)event
{
    NSIndexPath *indexPath = [self.collectionView indexPathForItem:self];
    
    self.collectionView.selectionIndexPaths = [NSSet setWithObject:indexPath];
    
    return [super rightMouseDown:event];
}

@end
