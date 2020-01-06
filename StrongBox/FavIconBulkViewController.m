//
//  FavIconBulkViewController.m
//  Strongbox
//
//  Created by Mark on 27/11/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "FavIconBulkViewController.h"
#import "NSArray+Extensions.h"
#import "FavIconManager.h"
#import "FavIconDownloadResultsViewController.h"
#import "Alerts.h"
#import "Settings.h"

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
@property NSMutableDictionary<NSURL*, NSArray<UIImage*>*>* results;
@property NSOperationQueue* queue;
@property NSArray<Node*> *validNodes;
@property NSArray<NSURL*> *validUniqueUrls;
@property NSArray<Node*> *nodes;
@property (nonatomic, copy) FavIconBulkDoneBlock onDone;

// Used in Item Details edit mode - where the URL can be different (new compared with whats in the Node?)
@property NSURL* singleNodeUrlOverride;

@end

@implementation FavIconBulkViewController

+ (void)presentModal:(UIViewController *)presentingVc node:(id)node urlOverride:(NSString *)urlOverride onDone:(FavIconBulkDoneBlock)onDone {
    [FavIconBulkViewController presentModal:presentingVc nodes:@[node] urlOverride:urlOverride onDone:onDone];
}

+ (void)presentModal:(UIViewController *)presentingVc nodes:(NSArray<Node *> *)nodes onDone:(FavIconBulkDoneBlock)onDone {
    [FavIconBulkViewController presentModal:presentingVc nodes:nodes urlOverride:nil onDone:onDone];
}

+ (void)presentModal:(UIViewController *)presentingVc
               nodes:(NSArray<Node *> *)nodes
         urlOverride:(NSString *)urlOverride
              onDone:(FavIconBulkDoneBlock)onDone {
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"FavIconBulk" bundle:nil];
    UINavigationController *nav = [sb instantiateInitialViewController];
//    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    
    FavIconBulkViewController* vc = (FavIconBulkViewController*)nav.topViewController;
    
    vc.nodes = nodes;
    vc.onDone = onDone;
    vc.singleNodeUrlOverride = [NSURL URLWithString:urlOverride];
    
    [presentingVc presentViewController:nav animated:YES completion:NULL];
}

- (void)loadAndValidateNodesAndUrls {
    BOOL overwriteExisting = self.switchOverwriteExisting.on;

    self.validNodes = @[];
    self.validUniqueUrls = @[];

    if(self.singleNodeUrlOverride) {
        if(self.nodes.count != 1 || self.singleNodeUrlOverride.absoluteString.length == 0) {
            return;
        }
        
        Node* singleton = self.nodes.firstObject;
        
        if(singleton.isGroup) {
            return;
        }

        if(overwriteExisting || singleton.isUsingKeePassDefaultIcon) {
            self.validNodes = @[singleton];
            self.validUniqueUrls = @[self.singleNodeUrlOverride];
        }
    }
    else {
        self.validNodes = [[self.nodes filter:^BOOL(Node * _Nonnull obj) {
            return !obj.isGroup &&
            obj.fields.url.length != 0 &&
            [NSURL URLWithString:obj.fields.url] != nil &&
            (overwriteExisting || obj.isUsingKeePassDefaultIcon);
        }] sortedArrayUsingComparator:finderStyleNodeComparator];

        NSMutableSet<NSURL*> *added = [NSMutableSet setWithCapacity:self.nodes.count];
        NSMutableArray<NSURL*> *addedArray = [NSMutableArray arrayWithCapacity:self.nodes.count];
        
        for (Node* node in self.validNodes) {
            NSURL* url = [NSURL URLWithString:node.fields.url];
            if(![added containsObject:url]) {
                [added addObject:url];
                [addedArray addObject:url];
            }
        }
        
        self.validUniqueUrls = addedArray.copy;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];

    if (@available(iOS 13.0, *)) {
        [self.navigationController setModalInPresentation:YES]; // Prevent Swipe down easy dismissal...
    }
    
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onStartStop)];
    singleTap.numberOfTapsRequired = 1;
    [self.imageViewStartStop addGestureRecognizer:singleTap];

    [self loadAndValidateNodesAndUrls];
    
    self.queue = [NSOperationQueue new];
    self.queue.maxConcurrentOperationCount = 8;
    
    self.results = @{}.mutableCopy;
    
    self.options = FavIconDownloadOptions.defaults;
 
    [self bindUi];
    
    if(self.validUniqueUrls.count == 1) {
        // Express kick off if only 1 item
        
        [self onStartStop];
    }
}

- (void)bindUi {
    self.statusLabel.text = [self getStatusString];
    
    [self.barButtonPreferences setEnabled:!(
        self.status == kFavIconBulkStatusInProgress ||
        self.status == kFavIconBulkStatusPausing)];

    self.buttonViewResults.hidden = self.buttonRetry.hidden =
        self.results.count == 0 ||
        self.validUniqueUrls.count == 0 ||
        self.status == kFavIconBulkStatusInProgress ||
        self.status == kFavIconBulkStatusPausing;
    
    NSUInteger errored = [self.results.allValues filter:^BOOL(NSArray<UIImage *> * _Nonnull obj) {
        return obj.count == 0;
    }].count;
    
    self.labelSuccesses.text = self.validUniqueUrls.count == 0 ? @"" : @(self.results.count - errored).stringValue;
    self.errorCountLabel.text = self.validUniqueUrls.count == 0 ? @"" : @(errored).stringValue;
    
    self.progressLabel.text = [NSString stringWithFormat:@"%lu/%lu", (unsigned long)self.results.count, (unsigned long)self.validUniqueUrls.count];
    self.progressLabel.hidden = self.validUniqueUrls.count == 0;
    
    self.progressView.progress = self.validUniqueUrls.count == 0 ? 0 : (float)self.results.count / (float)self.validUniqueUrls.count;
    
    [self bindStartStopStatusImage:errored];
}

- (void)bindStartStopStatusImage:(NSUInteger)errored {
    if(self.validUniqueUrls.count == 0) {
        [self.imageViewStartStop setImage:[UIImage imageNamed:@"cancel"]];
        self.imageViewStartStop.tintColor = UIColor.systemGrayColor;
        self.imageViewStartStop.userInteractionEnabled = NO;
        return;
    }
    
    if(self.status == kFavIconBulkStatusInitial ||
       self.status == kFavIconBulkStatusPaused) {
        [self.imageViewStartStop setImage:[UIImage imageNamed:@"Play"]];

        self.imageViewStartStop.tintColor = self.validUniqueUrls.count > 0 ? nil : UIColor.systemGrayColor;

        self.imageViewStartStop.userInteractionEnabled = self.validUniqueUrls.count > 0;
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
        else if (errored == self.validUniqueUrls.count) {
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
    if(self.validUniqueUrls.count == 0) {
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
    if(self.status == kFavIconBulkStatusInitial && self.validUniqueUrls.count > 0) {
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
    NSArray<NSURL*>* errored = [self.results.allKeys filter:^BOOL(NSURL * _Nonnull obj) {
        return self.results[obj].count == 0;
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
    else if (errored.count == self.results.count) {
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
    [self.results removeAllObjects];
    
    [self bindUi];
    
    [self startOrResume];
}

- (void)retryFailed {
    NSArray<NSURL*>* errored = [self.results.allKeys filter:^BOOL(NSURL * _Nonnull obj) {
        return self.results[obj].count == 0;
    }];

    [self.results removeObjectsForKeys:errored];
    
    [self bindUi];
    
    [self startOrResume];
}

- (void)startOrResume {
    self.status = kFavIconBulkStatusInProgress;

    self.queue.suspended = YES;

    NSMutableArray<NSURL*>* todo = self.validUniqueUrls.mutableCopy;
    
    for (NSURL* done in self.results) {
        [todo removeObject:done];
    }
    
    [FavIconManager.sharedInstance getFavIconsForUrls:todo
                                                queue:self.queue
                                              options:Settings.sharedInstance.favIconDownloadOptions
                                         withProgress:^(NSURL * _Nonnull url, NSArray<UIImage *> * _Nonnull images) {
        [self onProgressUpdate:url images:images];
    }];

    self.queue.suspended = NO;

    [self bindUi];
}

- (void)pause {
    // Pause is actually a full on cancel... Resume/Start just finds items that we don't have results for and queues them up
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

- (void)onProgressUpdate:(NSURL*)url images:(NSArray<UIImage *>* _Nonnull)images {
    self.results[url] = images;
    
    if(self.results.count == self.validUniqueUrls.count) {
        self.status = kFavIconBulkStatusDone;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self bindUi];
        
        if(self.status == kFavIconBulkStatusDone) {
            NSUInteger errored = [self.results.allValues filter:^BOOL(NSArray<UIImage *> * _Nonnull obj) {
                return obj.count == 0;
            }].count;
            
            if (errored == 0) { // Auto Segue if everything was successful
                [self onPreviewResults:nil];
            }
        }
    });
}

- (IBAction)onPreviewResults:(id)sender {
    if (self.results.count > 0) {
        [self performSegueWithIdentifier:@"segueToFavIconDownloadedResults" sender:nil];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"segueToFavIconDownloadedResults"]) {
        FavIconDownloadResultsViewController* vc = (FavIconDownloadResultsViewController*)segue.destinationViewController;
        
        vc.results = self.results;
        vc.nodes = self.validNodes;
        vc.singleNodeUrlOverride = self.singleNodeUrlOverride;
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
