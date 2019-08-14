//
//  QRCodeScannerViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 21/01/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "QRCodeScannerViewController.h"
#import "MTBBarcodeScanner.h"
#import "Alerts.h"

@interface QRCodeScannerViewController ()

@end

@implementation QRCodeScannerViewController

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    MTBBarcodeScanner *s = [[MTBBarcodeScanner alloc] initWithMetadataObjectTypes:@[AVMetadataObjectTypeQRCode]
                                                                  previewView:self.cameraView];

    [MTBBarcodeScanner requestCameraPermissionWithSuccess:^(BOOL success) {
        if (success) {
            NSError *error = nil;
            [s startScanningWithResultBlock:^(NSArray *codes) {
                for(AVMetadataMachineReadableCodeObject *code in codes) {
                    NSLog(@"Found code: %@", code);
                }
                [s stopScanning];
                
                AVMetadataMachineReadableCodeObject *code = codes.firstObject;
                self.onDone(YES, code.stringValue);
            } error:&error];
            
            if(error) {
                [Alerts error:self
                        title:NSLocalizedString(@"qr_code_vc_error_scanning_title", @"Error while scanning")
                        error:error
                   completion:^{
                    self.onDone(NO, @"");
                }];
            }
        } else {
            NSLog(@"The user denied access to the camera");
            [Alerts info:self
                   title:NSLocalizedString(@"qr_code_vc_warn_problem_accessing_camera_title", @"Could not access camera")
                 message:NSLocalizedString(@"qr_code_vc_warn_problem_accessing_camera_message", @"Strongbox could not access the camera on this device. Does it have permission?")
              completion:^{
                self.onDone(NO, @"");
            }];
        }
    }];
}

- (IBAction)onCancel:(id)sender {
    self.onDone(NO, @"");
}

@end
