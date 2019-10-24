//
//  LocalHttpServerViewController.m
//  Strongbox
//
//  Created by Mark on 08/10/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "LocalHttpServerViewController.h"
#import "GCDWebUploader.h"
#import "FileManager.h"

@interface LocalHttpServerViewController ()

@property GCDWebUploader* webUploader;

@property (weak, nonatomic) IBOutlet UILabel *serverUrl;
@property (weak, nonatomic) IBOutlet UILabel *helpfulInfo;

@end

@implementation LocalHttpServerViewController

- (void)viewWillAppear:(BOOL)animated {
    if(!self.webUploader.isRunning) {
        [self.webUploader startWithPort:80 bonjourName:nil];

        NSLog(@"Visit %@ in your web browser", self.webUploader.serverURL);

        if(self.webUploader.serverURL) {
            self.helpfulInfo.hidden = NO;
            self.serverUrl.text = self.webUploader.serverURL.absoluteString;
        }
        else {
            self.helpfulInfo.hidden = YES;
            self.serverUrl.text = NSLocalizedString(@"transfer_local_network_network_unavailable_message", @"Message to display when device is offline and has no IP address in Local HTTP Transfer - Select Storage -> Transfer over Local Network");
        }
    }
}

- (void)viewDidDisappear:(BOOL)animated {   
    if (self.webUploader.isRunning) {
        [self.webUploader stop];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSArray* bl = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* documentsPath = [bl firstObject];
    self.webUploader = [[GCDWebUploader alloc] initWithUploadDirectory:documentsPath];
}

@end
