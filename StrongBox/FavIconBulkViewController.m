//
//  FavIconBulkViewController.m
//  Strongbox
//
//  Created by Mark on 27/11/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "FavIconBulkViewController.h"
#import "NSArray+Extensions.h"
#import "FavIconManager.h"
#import "FavIconDownloadResultsViewController.h"
#import "Alerts.h"
#import "FavIconDownloadOptions.h"
#import "AppPreferences.h"
#import "NSString+Extensions.h"
#import "ConcurrentMutableDictionary.h"

typedef NS_ENUM (NSInteger, FavIconBulkDownloadStatus) {
    kFavIconBulkStatusInitial,
    kFavIconBulkStatusPausing,
    kFavIconBulkStatusPaused,
    kFavIconBulkStatusInProgress,
    kFavIconBulkStatusDone,
};

@interface FavIconBulkViewController ()

@property (weak, nonatomic) IBOutlet UILabel *progressLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (weak, nonatomic) IBOutlet UILabel *errorCountLabel;
@property (weak, nonatomic) IBOutlet UISwitch *switchOverwriteExisting;
@property (weak, nonatomic) IBOutlet UIButton *buttonRetry;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UIButton *buttonViewResults;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewStartStop;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *barButtonPreferences;
@property (weak, nonatomic) IBOutlet UILabel *labelSuccesses;

@property FavIconDownloadOptions* options;
@property FavIconBulkDownloadStatus status;

@property NSOperationQueue* queue;
@property NSArray<NSUUID*> *validNodes;

@property ConcurrentMutableDictionary<NSUUID*, NSArray<NodeIcon*>*>* nodeImagesMap;

@property NSArray<Node*> *nodes;
@property (nonatomic, copy) FavIconBulkDoneBlock onDone;


@property NSURL* singleNodeUrlOverride;

@property Model* model;

@end

@implementation FavIconBulkViewController

+ (void)presentModal:(UIViewController *)presentingVc model:(Model*)model node:(id)node urlOverride:(NSString *)urlOverride onDone:(FavIconBulkDoneBlock)onDone {
    [FavIconBulkViewController presentModal:presentingVc model:model nodes:@[node] urlOverride:urlOverride onDone:onDone];
}

+ (void)presentModal:(UIViewController *)presentingVc model:(Model*)model nodes:(NSArray<Node *> *)nodes onDone:(FavIconBulkDoneBlock)onDone {
    [FavIconBulkViewController presentModal:presentingVc model:model nodes:nodes urlOverride:nil onDone:onDone];
}

+ (void)presentModal:(UIViewController *)presentingVc
               model:(Model*)model
               nodes:(NSArray<Node *> *)nodes
         urlOverride:(NSString *)urlOverride
              onDone:(FavIconBulkDoneBlock)onDone {
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"FavIconBulk" bundle:nil];
    UINavigationController *nav = [sb instantiateInitialViewController];

    
    FavIconBulkViewController* vc = (FavIconBulkViewController*)nav.topViewController;
    
    vc.model = model;
    vc.nodes = nodes;
    vc.onDone = onDone;
    vc.singleNodeUrlOverride = urlOverride ? urlOverride.urlExtendedParse : nil;
    
    [presentingVc presentViewController:nav animated:YES completion:NULL];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.navigationController setModalInPresentation:YES]; 
    
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onStartStop)];
    singleTap.numberOfTapsRequired = 1;
    [self.imageViewStartStop addGestureRecognizer:singleTap];
    
    [self loadAndValidateNodesAndUrls];
    
    self.queue = [NSOperationQueue new];
    self.queue.maxConcurrentOperationCount = 8;
    
    self.nodeImagesMap = ConcurrentMutableDictionary.mutableDictionary;

    self.options = FavIconDownloadOptions.defaults;
    
    [self bindUi];
    
    if(self.validNodes.count == 1) {
        
        
        [self onStartStop];
    }
}

- (BOOL)urlIsValid:(NSString*)url {
    if ( url.length == 0 ) {
        return NO;
    }
    
    NSURL* urlParsed = url.urlExtendedParseAddingDefaultScheme;
    
    if ( url == nil || urlParsed.scheme.length == 0 ) {
        return NO;
    }
    
    return YES;
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
    BOOL overwriteExisting = self.switchOverwriteExisting.on;
    
    if ( self.singleNodeUrlOverride && self.nodes.count > 0 ) {
        self.validNodes = [self urlIsValid:self.singleNodeUrlOverride.absoluteString] ? @[self.nodes.firstObject.uuid] : @[];
    }
    else {
        self.validNodes = [[[self.nodes filter:^BOOL(Node * _Nonnull obj) {
            return [self isValidFavIconableNode:obj overwriteExisting:overwriteExisting];
        }] sortedArrayUsingComparator:finderStyleNodeComparator] map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
            return obj.uuid;
        }];
    }
}

- (void)bindUi {
    self.statusLabel.text = [self getStatusString];
    
    [self.barButtonPreferences setEnabled:!(
        self.status == kFavIconBulkStatusInProgress ||
        self.status == kFavIconBulkStatusPausing)];

    self.buttonRetry.hidden = self.validNodes.count == 0 ||
        self.status == kFavIconBulkStatusInProgress ||
        self.status == kFavIconBulkStatusPausing;

    BOOL atLeastOneResult = [self.nodeImagesMap.allValues anyMatch:^BOOL(NSArray<NodeIcon*> * _Nonnull obj) {
        return obj.count > 0;
    }];
    
    self.buttonViewResults.hidden = !atLeastOneResult ||
        self.status == kFavIconBulkStatusInProgress ||
        self.status == kFavIconBulkStatusPausing;
    
    NSUInteger errored = [self.nodeImagesMap.allValues filter:^BOOL(NSArray<UIImage *> * _Nonnull obj) {
        return obj.count == 0;
    }].count;
    
    self.labelSuccesses.text = self.validNodes.count == 0 ? @"" : @(self.nodeImagesMap.count - errored).stringValue;
    self.errorCountLabel.text = self.validNodes.count == 0 ? @"" : @(errored).stringValue;
    
    self.progressLabel.text = [NSString stringWithFormat:@"%lu/%lu", (unsigned long)self.nodeImagesMap.count, (unsigned long)self.validNodes.count];
    self.progressLabel.hidden = self.validNodes.count == 0;
    
    self.progressView.progress = self.validNodes.count == 0 ? 0 : (float)self.nodeImagesMap.count / (float)self.validNodes.count;
    
    [self bindStartStopStatusImage:errored];
}

- (void)bindStartStopStatusImage:(NSUInteger)errored {
    if(self.validNodes.count == 0) {
        [self.imageViewStartStop setImage:[UIImage imageNamed:@"cancel"]];
        self.imageViewStartStop.tintColor = UIColor.systemGrayColor;
        self.imageViewStartStop.userInteractionEnabled = NO;
        return;
    }
    
    if(self.status == kFavIconBulkStatusInitial ||
       self.status == kFavIconBulkStatusPaused) {
        [self.imageViewStartStop setImage:[UIImage imageNamed:@"Play"]];

        self.imageViewStartStop.tintColor = self.validNodes.count > 0 ? nil : UIColor.systemGrayColor;

        self.imageViewStartStop.userInteractionEnabled = self.validNodes.count > 0;
    }
    else if(self.status == kFavIconBulkStatusInProgress) {
        [self.imageViewStartStop setImage:[UIImage imageNamed:@"Pause"]];
        self.imageViewStartStop.tintColor = nil;
        self.imageViewStartStop.userInteractionEnabled = YES;
    }
    else if(self.status == kFavIconBulkStatusPausing) {
        self.imageViewStartStop.tintColor = UIColor.systemGrayColor;
        self.imageViewStartStop.userInteractionEnabled = NO;
    }
    else if(self.status == kFavIconBulkStatusDone) {
        if(errored == 0) {
         [self.imageViewStartStop setImage:[UIImage imageNamed:@"ok"]];
            self.imageViewStartStop.tintColor = UIColor.systemGreenColor;
        }
        else if (errored == self.validNodes.count) {
            [self.imageViewStartStop setImage:[UIImage imageNamed:@"cancel"]];
            self.imageViewStartStop.tintColor = UIColor.systemRedColor;
        }
        else {
            [self.imageViewStartStop setImage:[UIImage imageNamed:@"ok"]];
            self.imageViewStartStop.tintColor = UIColor.systemYellowColor;
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

- (IBAction)onCancel:(id)sender {
    [self.queue cancelAllOperations];
    self.queue = nil;
    
    self.onDone(NO, nil);
}

- (void)onStartStop {
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

- (IBAction)onRetry:(id)sender {
    NSArray<NSUUID*>* errored = [self.nodeImagesMap.allKeys filter:^BOOL(NSUUID * _Nonnull obj) {
        return self.nodeImagesMap[obj].count == 0;
    }];

    if(errored.count == 0) {
        [Alerts yesNo:self
                title:NSLocalizedString(@"generic_are_you_sure", @"Are you sure?")
              message:NSLocalizedString(@"favicon_clear_all_and_retry_message", @"Are you sure you want to clear current results and retry all items?")
               action:^(BOOL response) {
            if(response) {
                [self retryAll];
            }
        }];
    }
    else if (errored.count == self.nodeImagesMap.count) {
        [self retryAll];
    }
    else {
        [Alerts twoOptionsWithCancel:self
                               title:NSLocalizedString(@"favicon_retry_all_or_failed_title", @"Retry All or Failed?")
                             message:NSLocalizedString(@"favicon_retry_all_or_failed_message", @"Would you like to retry all items, or just the failed ones?")
                   defaultButtonText:NSLocalizedString(@"favicon_retry_all_action", @"Retry All")
                    secondButtonText:NSLocalizedString(@"favicon_retry_failed_action", @"Retry Failed")
                              action:^(int response) {
            if(response == 0) {
                [self retryAll];
            }
            else if (response == 1) {
                [self retryFailed];
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
    NSArray<NSUUID*>* errored = [self.nodeImagesMap.allKeys filter:^BOOL(NSUUID * _Nonnull obj) {
        return self.nodeImagesMap[obj].count == 0;
    }];

    [self.nodeImagesMap removeObjectsForKeys:errored];
    
    [self bindUi];
    
    [self startOrResume];
}

- (void)startOrResume {
    self.status = kFavIconBulkStatusInProgress;
    
    self.queue.suspended = YES;
    
    NSMutableArray<NSUUID*>* remaining = self.validNodes.mutableCopy;
    
    for ( NSUUID* alreadyDone in self.nodeImagesMap.allKeys ) {
        [remaining removeObject:alreadyDone];
    }
    
    for ( NSUUID* uuid in remaining ) {
        Node* node = [self.model getItemById:uuid];
        if ( node == nil ) {
            node = [self.nodes firstOrDefault:^BOOL(Node * _Nonnull obj) {
                return [obj.uuid isEqual:uuid];
            }];
        }
        
        if (!node) {
            continue;
        }
        
        NSSet<NSURL*>* urls = self.singleNodeUrlOverride ? [NSSet setWithObject:self.singleNodeUrlOverride] : [self getUrlsForNode:node];
        
        [FavIconManager.sharedInstance getFavIconsForUrls:urls.allObjects
                                                    queue:self.queue
                                                  options:AppPreferences.sharedInstance.favIconDownloadOptions
                                               completion:^(NSArray<NodeIcon*> * _Nonnull images) {
            [self onProgressUpdate:uuid images:images];
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

- (void)onProgressUpdate:(NSUUID*)uuid images:(NSArray<NodeIcon*>* _Nonnull)images {
    self.nodeImagesMap[uuid] = images;
    
    
    
    if(self.nodeImagesMap.count == self.validNodes.count) {
        self.status = kFavIconBulkStatusDone;
    }
    
    
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self bindUi];
        
        if(self.status == kFavIconBulkStatusDone) {
            NSUInteger errored = [self.nodeImagesMap.allValues filter:^BOOL(NSArray<NodeIcon*> * _Nonnull obj) {
                return obj.count == 0;
            }].count;
            
            if (errored == 0) { 
                [self onPreviewResults:nil];
            }
        }
    });
}

- (IBAction)onPreviewResults:(id)sender {
    if (self.nodeImagesMap.count > 0) {
        [self performSegueWithIdentifier:@"segueToFavIconDownloadedResults" sender:nil];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"segueToFavIconDownloadedResults"]) {
        FavIconDownloadResultsViewController* vc = (FavIconDownloadResultsViewController*)segue.destinationViewController;
        
        vc.nodes = self.nodes;
        vc.nodeImagesMap = self.nodeImagesMap;
        vc.validNodes = self.validNodes;
        vc.onDone = self.onDone;
    }
}

- (IBAction)onOverwriteExistingChanged:(id)sender {
    [self loadAndValidateNodesAndUrls];
    [self bindUi];
}

- (IBAction)onFavIconPreferences:(id)sender {
    [self performSegueWithIdentifier:@"segueToFavIconPreferences" sender:nil];
}

@end
