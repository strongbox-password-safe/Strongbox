//
//  FavIconDownloader.m
//  Strongbox
//
//  Created by Mark on 17/12/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "FavIconDownloader.h"
#import "NSArray+Extensions.h"
#import "FavIconManager.h"
#import "Settings.h"
#import "FavIconResultTableCellView.h"
#import "Utils.h"
#import "NodeIconHelper.h"
#import "MacAlerts.h"
#import "NSString+Extensions.h"
#import "ConcurrentMutableDictionary.h"

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

@interface FavIconDownloader () <NSTableViewDataSource>

typedef NS_ENUM (NSInteger, FavIconBulkDownloadStatus) {
    kFavIconBulkStatusInitial,
    kFavIconBulkStatusPausing,
    kFavIconBulkStatusPaused,
    kFavIconBulkStatusInProgress,
    kFavIconBulkStatusDone,
};

@property (weak) IBOutlet NSButton *buttonIncludeItemsWithCustomIcons;
@property (weak) IBOutlet NSTextField *statusLabel;

@property (weak) IBOutlet NSButton *buttonViewResults;
@property (weak) IBOutlet NSButton *buttonRetry;
@property (weak) IBOutlet NSTextField *labelSuccesses;
@property (weak) IBOutlet NSTextField *errorCountLabel;
@property (weak) IBOutlet NSTextField *progressLabel;
@property (weak) IBOutlet NSProgressIndicator *progressView;
@property (weak) IBOutlet NSButton *imageViewStartStop;
@property (weak) IBOutlet NSTabView *tabView;
@property (weak) IBOutlet NSTableView *tableViewResults;
@property (weak) IBOutlet NSTableView *tableViewSelectPreferred;

@property NSArray<Node*> *validNodes;
@property FavIconBulkDownloadStatus status;

@property ConcurrentMutableDictionary<NSUUID*, NSArray<NodeIcon*>*>* nodeImagesMap;

@property NSOperationQueue* queue;

@property NSMutableDictionary<NSUUID*, NSNumber*> *nodeSelected;
@property (weak) IBOutlet NSButton *buttonSetIcons;

@property Node* nodeToChoosePreferredIconsFor;
@property BOOL hasLoaded;

@end

@implementation FavIconDownloader

+ (instancetype)newVC {
    NSStoryboard* sb = [NSStoryboard storyboardWithName:@"DownloadFavIcons" bundle:nil];

    FavIconDownloader* instance = [sb instantiateInitialController];

    return instance;
}

- (void)viewWillAppear {
    [super viewWillAppear];



    if(!self.hasLoaded) {
        self.hasLoaded = YES;
        [self doInitialSetup];
    }
}

- (void)doInitialSetup {
    [self.tableViewResults registerNib:[[NSNib alloc] initWithNibNamed:@"FavIconResultTableCell" bundle:nil] forIdentifier:@"FavIconResultTableCellIdentifier"];
    self.tableViewResults.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone;
    
    self.tableViewSelectPreferred.action = @selector(onClickPreferredIcon:);
    
    [self.tabView setTabViewType:NSNoTabsLineBorder];
    self.imageViewStartStop.focusRingType = NSFocusRingTypeNone;

    [self loadAndValidateNodesAndUrls];
    
    self.queue = [NSOperationQueue new];
    self.queue.maxConcurrentOperationCount = 8;

    self.nodeImagesMap = ConcurrentMutableDictionary.mutableDictionary;
    self.nodeSelected = @{}.mutableCopy;
    
    [self bindUi];
  
    
    

        [self onStartStop:nil];

}

- (BOOL)urlIsValid:(NSString*)url {
    return url.length != 0 && url.urlExtendedParse != nil;
}

- (NSSet<NSURL*>*)getUrlsForNode:(Node*)obj {
    NSMutableSet* ret = NSMutableSet.set;
    
    if ( [self urlIsValid:obj.fields.url] ) {
        [ret addObject:obj.fields.url.urlExtendedParse];
    }
    
    NSArray<NSURL*>* alts = [obj.fields.alternativeUrls map:^id _Nonnull(NSString * _Nonnull obj, NSUInteger idx) {
        return obj.urlExtendedParse;
    }];
    
    [ret addObjectsFromArray:alts];
    
    return ret;
}

- (BOOL)isValidFavIconableNode:(Node*)obj overwriteExisting:(BOOL)overwriteExisting {
    if ( obj.isGroup ) {
        return NO;
    }
    
    if ( !overwriteExisting && !obj.icon.isCustom ) {
        return NO;
    }
    
    return [self getUrlsForNode:obj].anyObject != nil;
}

- (void)loadAndValidateNodesAndUrls {
    BOOL overwriteExisting = self.buttonIncludeItemsWithCustomIcons.state == NSControlStateValueOn;
    
    self.validNodes = [[self.nodes filter:^BOOL(Node * _Nonnull obj) {
        return [self isValidFavIconableNode:obj overwriteExisting:overwriteExisting];
    }] sortedArrayUsingComparator:finderStyleNodeComparator];
}

- (void)bindUi {
    self.statusLabel.stringValue = [self getStatusString];

    self.buttonIncludeItemsWithCustomIcons.enabled =

    self.buttonViewResults.hidden = self.buttonRetry.hidden =
        self.nodeImagesMap.count == 0 ||
        self.validNodes.count == 0 ||
        self.status == kFavIconBulkStatusInProgress ||
        self.status == kFavIconBulkStatusPausing;

    NSUInteger errored = [self.nodeImagesMap.allValues filter:^BOOL(NSArray<NSImage *> * _Nonnull obj) {
        return obj.count == 0;
    }].count;

    self.labelSuccesses.stringValue = self.validNodes.count == 0 ? @"" : @(self.nodeImagesMap.count - errored).stringValue;
    self.errorCountLabel.stringValue = self.validNodes.count == 0 ? @"" : @(errored).stringValue;

    self.progressLabel.stringValue = [NSString stringWithFormat:@"%lu/%lu", (unsigned long)self.nodeImagesMap.count, (unsigned long)self.validNodes.count];
    self.progressLabel.hidden = self.validNodes.count == 0;

    self.progressView.doubleValue = self.validNodes.count == 0 ? 0 : (((float)self.nodeImagesMap.count / (float)self.validNodes.count) * 100);

    BOOL featureAvailable = Settings.sharedInstance.isPro;
    
    if(!featureAvailable) {
        NSString* loc = NSLocalizedString(@"mac_button_set_favicons_pro_only", @"Set Icons (Pro Only)");
        [self.buttonSetIcons setTitle:loc];
    }
    
    self.buttonSetIcons.enabled = self.nodeSelected.count > 0 && featureAvailable;
    
    [self bindStartStopStatusImage:errored];
}

- (void)bindStartStopStatusImage:(NSUInteger)errored {
    if(self.validNodes.count == 0) {
        [self.imageViewStartStop setImage:[NSImage imageNamed:@"cancel"]];
        [self.imageViewStartStop setContentTintColor:NSColor.redColor];
        
        self.imageViewStartStop.enabled = NO;
        return;
    }
    
    if(self.status == kFavIconBulkStatusInitial ||
       self.status == kFavIconBulkStatusPaused) {
        [self.imageViewStartStop setImage:[NSImage imageNamed:@"Play"]];
        self.imageViewStartStop.enabled = self.validNodes.count > 0;
    }
    else if(self.status == kFavIconBulkStatusInProgress) {
        [self.imageViewStartStop setImage:[NSImage imageNamed:@"Pause"]];
        [self.imageViewStartStop setContentTintColor:nil];
        
        self.imageViewStartStop.enabled = YES;
    }
    else if(self.status == kFavIconBulkStatusPausing) {
        [self.imageViewStartStop setContentTintColor:NSColor.systemGrayColor];
        self.imageViewStartStop.enabled = NO;
    }
    else if(self.status == kFavIconBulkStatusDone) {
        if(errored == 0) {
            [self.imageViewStartStop setImage:[NSImage imageNamed:@"ok"]];
            [self.imageViewStartStop setContentTintColor:NSColor.systemGreenColor];
        }
        else if (errored == self.validNodes.count) {
            [self.imageViewStartStop setImage:[NSImage imageNamed:@"cancel"]];
            [self.imageViewStartStop setContentTintColor:NSColor.redColor];
        }
        else {
            [self.imageViewStartStop setImage:[NSImage imageNamed:@"ok"]];
            [self.imageViewStartStop setContentTintColor:NSColor.systemYellowColor];
        }
    }
}

- (NSString*)getStatusString {
    if(self.validNodes.count == 0) {
        return NSLocalizedString(@"favicon_status_no_eligible_items", @"No eligible items with valid URLs found...");
    }
    
    switch(self.status) {
        case kFavIconBulkStatusInitial:
            return NSLocalizedString(@"favicon_status_initial", @"Tap Play to start search");
        case kFavIconBulkStatusInProgress:
            return NSLocalizedString(@"favicon_status_in_progress", @"Searching...");
        case kFavIconBulkStatusPausing:
            return NSLocalizedString(@"favicon_status_pausing", @"Pausing (may take a few seconds)...");
        case kFavIconBulkStatusPaused:
            return NSLocalizedString(@"favicon_status_paused", @"FavIcon search paused. Tap Play to Continue...");
        case kFavIconBulkStatusDone:
            return NSLocalizedString(@"favicon_status_done", @"Search Complete. Tap View Results to see FavIcons");
        default:
            return @"<Unknown>";
    }
}

- (IBAction)onBackToSearch:(id)sender {
    [self.tabView selectTabViewItemAtIndex:0];
}

- (IBAction)onStartStop:(id)sender {
    if(self.status == kFavIconBulkStatusInitial && self.validNodes.count > 0) {
        [self startOrResume];
    }
    else if (self.status == kFavIconBulkStatusInProgress) {
        [self pause];
    }
    else if (self.status == kFavIconBulkStatusPaused) {
        [self startOrResume];
    }
}

- (void)startOrResume {
    self.status = kFavIconBulkStatusInProgress;

    self.queue.suspended = YES;

    NSArray<NSUUID*>* done = self.nodeImagesMap.allKeys;
    
    NSMutableArray<Node*>* remaining = [self.validNodes filter:^BOOL(Node * _Nonnull obj) {
        return ![done containsObject:obj.uuid];
    }].mutableCopy;
    
    for ( Node* node in remaining ) {
        NSSet<NSURL*>* urls = [self getUrlsForNode:node];
        
        [FavIconManager.sharedInstance getFavIconsForUrls:urls.allObjects
                                                    queue:self.queue
                                                  options:Settings.sharedInstance.favIconDownloadOptions
                                               completion:^(NSArray<NodeIcon*> * _Nonnull images) {
            [self onProgressUpdate:node.uuid images:images];
        }];
    }

    self.queue.suspended = NO;

    [self bindUi];
}

- (void)pause {
    
    [self.queue cancelAllOperations];

    self.status = kFavIconBulkStatusPausing;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
        [self.queue waitUntilAllOperationsAreFinished];
        self.status = kFavIconBulkStatusPaused;

        dispatch_async(dispatch_get_main_queue(), ^{
            [self bindUi];
        });
    });

    [self bindUi];
}




- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return tableView == self.tableViewResults ? self.validNodes.count : (self.nodeToChoosePreferredIconsFor ? [self getSortedImagesForNode:self.nodeToChoosePreferredIconsFor.uuid].count : 0);
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if(tableView == self.tableViewResults) {
        return [self viewForFavIconResults:row];
    }
    else {
        return [self viewForSelectingPreferredFavIcon:row];
    }
}

- (NSView*)viewForFavIconResults:(NSInteger)row {
    FavIconResultTableCellView* cell = (FavIconResultTableCellView*)[self.tableViewResults makeViewWithIdentifier:@"FavIconResultTableCellIdentifier" owner:nil];
    
    if ( row >= self.validNodes.count ) {
        slog(@"🔴 WARNWARN: row greater than validNodes.count");
        return cell;
    }

    Node* node = self.validNodes[row];
    
    if ( node == nil ) {
        slog(@"🔴 WARNWARN: Could not find node?!");
        return cell;
    }
        
    NSNumber* selectedIndex = self.nodeSelected[node.uuid];
    NSArray<NodeIcon*> *images = [self getSortedImagesForNode:node.uuid];
    
    if ( selectedIndex != nil && selectedIndex.intValue >= images.count ) {
        slog(@"🔴 WARNWARN: Selected Index invalid");
        return cell;
    }
    
    NodeIcon* selectedImage = selectedIndex != nil ? images[selectedIndex.intValue] : nil;
    
    cell.title.stringValue = node.title;
    cell.checked = selectedImage != nil;
    cell.checkable = images.count > 0;
    
    if (images.count > 0) {
        
        
        cell.showIconChooseButton = YES;
        
        cell.onClickChooseIcon = ^{
            self.nodeToChoosePreferredIconsFor = node;
            [self refreshAndShowPreferredIconChooserTab];
        };

        

        __weak FavIconResultTableCellView* weakCell = cell;
        cell.onCheckChanged = ^{
             if(!weakCell.checked) {
                 [self.nodeSelected removeObjectForKey:node.uuid];
             }
             else {
                 NodeIcon* best = [FavIconManager.sharedInstance getIdealImage:images
                                                                       options:Settings.sharedInstance.favIconDownloadOptions];
                 
                 if ( best != nil ) {
                     self.nodeSelected[node.uuid] = @([images indexOfObject:best]);
                 }
                 else {
                     [MacAlerts info:NSLocalizedString(@"favicon_downloader_images_too_large", @"Could not auto select FavIcon because all available images are larger than the configured maximum. You must manually select it.")
                              window:self.view.window];
                 }
             }
             
            [self bindUi];
            [self.tableViewResults reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row]
                                              columnIndexes:[NSIndexSet indexSetWithIndex:0]];
        };

        cell.subTitle.textColor = nil;
        
        if(selectedImage) {
            cell.subTitle.stringValue = [NSString stringWithFormat:NSLocalizedString(@"favicon_results_n_icons_found_with_xy_resolution_fmt", @"%lu Icons Found (%dx%d selected)"),
                                         (unsigned long)images.count,
                                         (int)selectedImage.customIconWidth,
                                         (int)selectedImage.customIconHeight];

            NSImage* img = selectedImage.customIcon;
            if(selectedImage.customIconHeight != 32 || selectedImage.customIconWidth != 32) {
                img = scaleImage(selectedImage.customIcon, CGSizeMake(32, 32));
            }
    
            if (img.isValid) {
                cell.icon.image = img;
                cell.icon.hidden = NO;
            }
        }
        else {
            cell.subTitle.stringValue = [NSString stringWithFormat:NSLocalizedString(@"favicon_results_n_icons_found_none_selected_fmt", @"%lu Icons Found (None selected)"), (unsigned long)images.count];
            
            cell.icon.hidden = NO;
            cell.icon.image = [NSImage imageNamed:@"cancel"];
        }
    }
    else {
        cell.subTitle.stringValue = NSLocalizedString(@"favicon_results_no_icons_found", @"No FavIcons Found");
        cell.subTitle.textColor = NSColor.redColor;
        
        cell.showIconChooseButton = NO;
        cell.onClickChooseIcon = nil;
        cell.icon.image = [NSImage imageNamed:@"error"];
        cell.onCheckChanged = nil;
    }

    return cell;
}



- (void)onProgressUpdate:(NSUUID*)uuid images:(NSArray<NodeIcon*>* _Nonnull)images {
    self.nodeImagesMap[uuid] = images;

    
    
    if ( images.count ) {
        NSArray<NodeIcon*>* sorted = [self getSortedImagesForNode:uuid];
        NodeIcon* best = [FavIconManager.sharedInstance getIdealImage:sorted
                                                                   options:Settings.sharedInstance.favIconDownloadOptions];
        
        if ( best != nil ) {
            NSUInteger bestIndex = [sorted indexOfObject:best];
            self.nodeSelected[uuid] = @(bestIndex);
        }
    }

    
    
    if(self.nodeImagesMap.count == self.validNodes.count) {
        self.status = kFavIconBulkStatusDone;
    }

    
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self bindUi];
        
        if(self.status == kFavIconBulkStatusDone) {
            NSUInteger errored = [self.nodeImagesMap.allValues filter:^BOOL(NSArray<NodeIcon *> * _Nonnull obj) {
                return obj.count == 0;
            }].count;
            
            if (errored == 0) { 
                [self refreshAndDisplaySearchResults];
            }
        }
    });
}

- (IBAction)onViewResults:(id)sender {
    [self refreshAndDisplaySearchResults];
}

- (NSArray<NodeIcon*>*)getSortedImagesForNode:(NSUUID*)uuid {
    NSArray<NodeIcon*>* icons = self.nodeImagesMap[uuid];
    
    return [FavIconManager.sharedInstance getSortedImages:icons options:Settings.sharedInstance.favIconDownloadOptions];
}

- (void)refreshAndDisplaySearchResults {
    self.validNodes = [self.validNodes sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        Node* node1 = obj1;
        Node* node2 = obj2;

        NSArray<NodeIcon*> *images1 = [self getSortedImagesForNode:node1.uuid];
        NSArray<NodeIcon*> *images2 = [self getSortedImagesForNode:node2.uuid];

        return images1.count > 0 && images2.count > 0 ? finderStringCompare(node1.title, node2.title) : images1.count == 0 ? NSOrderedDescending : NSOrderedAscending;
    }];
    
    [self.tableViewResults reloadData];
    [self.tabView selectTabViewItemAtIndex:1];
}



- (void)refreshAndShowPreferredIconChooserTab {
    [self.tableViewSelectPreferred reloadData];
    
    NSNumber* currentlySelected = self.nodeSelected[self.nodeToChoosePreferredIconsFor.uuid];
    
    
      
    if(currentlySelected != nil) {
        NSArray<NodeIcon*>* images = [self getSortedImagesForNode:self.nodeToChoosePreferredIconsFor.uuid];
        NodeIcon* currentlySelectedImage = images[currentlySelected.intValue];
        NSUInteger row = [images indexOfObject:currentlySelectedImage];
        [self.tableViewSelectPreferred selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    }
    
    [self.tabView selectTabViewItemAtIndex:2];
}

- (NSView*)viewForSelectingPreferredFavIcon:(NSInteger)row {
    FavIconResultTableCellView* cell = (FavIconResultTableCellView*)[self.tableViewResults makeViewWithIdentifier:@"FavIconResultTableCellIdentifier" owner:nil];

    NSArray<NodeIcon*>* images = [self getSortedImagesForNode:self.nodeToChoosePreferredIconsFor.uuid];
    NodeIcon* icon = images[row];
    
    cell.title.stringValue = self.nodeToChoosePreferredIconsFor.title;
    cell.subTitle.stringValue = [NSString stringWithFormat:@"%dx%d (%@)", (int)icon.customIconWidth, (int)icon.customIconHeight, friendlyFileSizeString(icon.estimatedStorageBytes)];
    
    NSImage* img = icon.customIcon;
    if(icon.customIconHeight != 32 || icon.customIconWidth != 32) {
        img = scaleImage(img, CGSizeMake(32, 32));
    }
    
    if (img.isValid) {
        cell.icon.image = img;
    }
    
    return cell;
}

- (void)onClickPreferredIcon:(id)sender {
    NSUInteger selectedIndex = self.tableViewSelectPreferred.selectedRow;

    if(selectedIndex != -1) {
        self.nodeSelected[self.nodeToChoosePreferredIconsFor.uuid] = @(selectedIndex);
    }

    NSUInteger row = [self.validNodes indexOfObject:self.nodeToChoosePreferredIconsFor];
    
    [self.tableViewResults reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row] columnIndexes:[NSIndexSet indexSetWithIndex:0]];

    [self.tabView selectTabViewItemAtIndex:1];
}

- (IBAction)onRetry:(id)sender {
    NSArray<NSUUID*>* errored = [self.nodeImagesMap.allKeys filter:^BOOL(NSUUID* _Nonnull obj) {
        return self.nodeImagesMap[obj].count == 0;
    }];

    if(errored.count == 0) {
        [MacAlerts yesNo:NSLocalizedString(@"favicon_clear_all_and_retry_message", @"Are you sure you want to clear current results and retry all items?")
               window:self.view.window
           completion:^(BOOL yesNo) {
            if(yesNo) {
                [self retryAll];
            }
        }];
    }
    else {
        [MacAlerts twoOptionsWithCancel:NSLocalizedString(@"favicon_retry_all_or_failed_title", @"Retry All or Failed?")
                     informativeText:NSLocalizedString(@"favicon_retry_all_or_failed_message", @"Would you like to retry all items, or just the failed ones?")
                   option1AndDefault:NSLocalizedString(@"favicon_retry_failed_action", @"Retry Failed")
                             option2:NSLocalizedString(@"favicon_retry_all_action", @"Retry All")
                              window:self.view.window
                             completion:^(int response) {
            if(response == 0) {
                [self retryFailed];
            }
            else if (response == 1) {
                [self retryAll];
            }
        }];
    }
}

- (void)retryAll {
    [self.nodeImagesMap removeAllObjects];
    
    [self bindUi];
    
    [self startOrResume];
}

- (void)retryFailed {
    NSArray<NSUUID*>* errored = [self.nodeImagesMap.allKeys filter:^BOOL(NSUUID* _Nonnull obj) {
        return self.nodeImagesMap[obj].count == 0;
    }];

    [self.nodeImagesMap removeObjectsForKeys:errored];
    
    [self bindUi];
    
    [self startOrResume];
}

- (IBAction)onIncludeItemsWithCustomIcons:(id)sender {
    [self loadAndValidateNodesAndUrls];
    [self bindUi];
}

- (IBAction)onCancel:(id)sender {
    [self.queue cancelAllOperations];
    self.queue = nil;
        
    if (self.onDone) {
        self.onDone(NO, nil);
    }
        
    [self.presentingViewController dismissViewController:self]; 
}

- (IBAction)onSetIcons:(id)sender {
    NSMutableDictionary<NSUUID*, NodeIcon*> *selected = @{}.mutableCopy;

    for (Node* node in self.validNodes) {
        NSNumber* index = self.nodeSelected[node.uuid];
        
        if(index != nil) {
            NSArray<NodeIcon*>* images = [self getSortedImagesForNode:node.uuid];
            selected[node.uuid] = images[index.intValue];
        }
    }

    
    
    if(selected.count > 1) {
        NSString* loc = NSLocalizedString(@"set_favicons_are_you_sure_yes_no_fmt", @"This will set the icons for %d items to your selected FavIcons. Are you sure you want to continue?");
        
        NSString *info = [NSString stringWithFormat:loc, selected.count];
        [MacAlerts yesNo:NSLocalizedString(@"generic_are_you_sure", @"Are you sure?")
      informativeText:info
               window:self.view.window
           completion:^(BOOL yesNo) {
            if(yesNo) {
                if (self.onDone) {
                    [self.queue cancelAllOperations];
                    self.queue = nil;
                    self.onDone(YES, selected);
                }
                
                [self.presentingViewController dismissViewController:self];
            }
        }];
    }
    else {
        if (self.onDone) {
            [self.queue cancelAllOperations];
            self.queue = nil;
            self.onDone(YES, selected);
        }
        
        [self.presentingViewController dismissViewController:self];
    }
}

@end
