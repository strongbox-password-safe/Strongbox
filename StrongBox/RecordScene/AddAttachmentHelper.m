//
//  AddAttachmentHelper.m
//  Strongbox-iOS
//
//  Created by Mark on 25/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "AddAttachmentHelper.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "Alerts.h"
#import "Utils.h"
#import "SVProgressHUD/SVProgressHUD.h"
#import "UiAttachment.h"

const int kMaxRecommendedAttachmentSize = 512 * 1024; // KB

@interface AddAttachmentHelper () <UIImagePickerControllerDelegate, UIDocumentPickerDelegate, UINavigationControllerDelegate>

@property UIViewController* parentViewController;
@property (nonatomic, copy) void (^onAdd)(UiAttachment * _Nonnull attachment);
@property NSSet<NSString*>* usedFilenames;

@end

@implementation AddAttachmentHelper

+ (instancetype)sharedInstance {
    static AddAttachmentHelper *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[AddAttachmentHelper alloc] init];
    });
    
    return sharedInstance;
}

- (void)beginAddAttachmentUi:(UIViewController *)vc usedFilenames:(NSArray<NSString *> *)usedFilenames onAdd:(void (^)(UiAttachment * _Nonnull))onAdd {
    self.parentViewController = vc;
    self.onAdd = onAdd;
    self.usedFilenames = [NSSet setWithArray:usedFilenames]; // Not case sensitive in original app - no need to lowercase
    
    UIAlertController *alertController =
    [UIAlertController alertControllerWithTitle:@"Attachment Location"
                                        message:nil
                                 preferredStyle:UIAlertControllerStyleAlert];
    
    NSArray<NSString*>* buttonTitles =
    @[  @"Photos",
        @"Files"];
    
    int index = 1;
    for (NSString *title in buttonTitles) {
        UIAlertAction *action = [UIAlertAction actionWithTitle:title
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction *a) {
                                                           [self onAddAttachmentLocationResponse:index];
                                                       }];
        [alertController addAction:action];
        index++;
    }
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *a) {
                                                             [self onAddAttachmentLocationResponse:0];
                                                         }];
    [alertController addAction:cancelAction];
    
    alertController.popoverPresentationController.sourceView = self.parentViewController.view;
    [self.parentViewController presentViewController:alertController animated:YES completion:nil];
}

- (void)onAddAttachmentLocationResponse:(int)response {
    if(response == 2) {
        UIDocumentPickerViewController *vc = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[(NSString*)kUTTypeItem] inMode:UIDocumentPickerModeImport];
        vc.delegate = self;
        vc.modalPresentationStyle = UIModalPresentationFormSheet;
        
        [self.parentViewController presentViewController:vc animated:YES completion:nil];
    }
    else if(response == 1) {
        UIImagePickerController *vc = [[UIImagePickerController alloc] init];
        vc.delegate = self;
        vc.videoQuality = UIImagePickerControllerQualityTypeHigh;
        vc.modalPresentationStyle = UIModalPresentationFormSheet;
        
        BOOL available = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary];
        
        if(!available) {
            [Alerts info:self.parentViewController title:@"Source Unavailable" message:@"Could not access photos source."];
            return;
        }
        
        vc.mediaTypes = @[(NSString*)kUTTypeMovie, (NSString*)kUTTypeImage];
        vc.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        
        [self.parentViewController presentViewController:vc animated:YES completion:nil];
    }
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSLog(@"didPickDocumentsAtURLs: %@", urls);
    
    NSURL* url = [urls objectAtIndex:0];
    
    NSError* error;
    NSData* data = [NSData dataWithContentsOfURL:url options:kNilOptions error:&error];
    
    if(!data) {
        NSLog(@"Error: %@", error);
        [Alerts warn:self.parentViewController title:@"Error Reading" message:@"Could not read the data for this item."];
        return;
    }
    
    NSString *filename = [url.absoluteString.lastPathComponent stringByRemovingPercentEncoding];
    [self addAttachment:filename data:data];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    NSLog(@"Image Pick did finish: [%@]", info);
    NSString* mediaType = [info objectForKey:UIImagePickerControllerMediaType];
    BOOL isImage = UTTypeConformsTo((__bridge CFStringRef)mediaType, kUTTypeImage) != 0;
    
    NSURL *url;
    NSData* data;
    
    if(isImage) {
        if (@available(iOS 11.0, *)) {
            url =  [info objectForKey:UIImagePickerControllerImageURL];
        } else {
            UIImage* image = [info objectForKey:UIImagePickerControllerOriginalImage];
            
            if(!image) {
                [Alerts warn:self.parentViewController title:@"Error Reading" message:@"Could not read the data for this item."];
                return;
            }
            
            data = UIImagePNGRepresentation(image);
        }
    }
    else {
        url =  [info objectForKey:UIImagePickerControllerMediaURL];
    }
    
    NSString *suggestedFilename;
    
    NSError* error;
    if(url) {
        data = [NSData dataWithContentsOfURL:url options:kNilOptions error:&error];
        suggestedFilename = [url.absoluteString.lastPathComponent stringByRemovingPercentEncoding];
    }
    suggestedFilename = suggestedFilename.length ? suggestedFilename : @"attachment";
    
    if(!data) {
        NSLog(@"Error: %@", error);
        
        [picker dismissViewControllerAnimated:YES completion:^{
            [Alerts warn:self.parentViewController title:@"Error Reading" message:@"Could not read the data for this item."];
        }];
        return;
    }

    [picker dismissViewControllerAnimated:YES completion:^{
        [self addAttachment:suggestedFilename data:data];
    }];
}

- (void)addAttachment:(NSString*)suggestedFilename data:(NSData*)data {
    if(data.length > kMaxRecommendedAttachmentSize) {
        UIImage* image = [UIImage imageWithData:data];
        
        if(image) {
            [self prepareLargeImageRescalingOptions:suggestedFilename image:image data:data];
        }
        else {
            NSString* message = [NSString stringWithFormat:@"This is quite a large file (%@), and could significantly affect the performance of Strongbox and slow down syncs across networks. Is there a smaller version you could use?\n\nContinue adding this attachment anyway?", friendlyFileSizeString(data.length)];

            [Alerts yesNo:self.parentViewController
                    title:@"Large Attachment"
                  message:message
                   action:^(BOOL response) {
                       if(response) {
                           [self addAttachmentNoWarn:suggestedFilename data:data];
                       }
                   }];
        }
    }
    else {
        [self addAttachmentNoWarn:suggestedFilename data:data];
    }
}

- (void)prepareLargeImageRescalingOptions:(NSString*)suggestedFilename image:(UIImage*)image data:(NSData*)data {
    [SVProgressHUD showWithStatus:@"Analyzing Image..."];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
        NSMutableDictionary<NSString*, NSData*> *resized = [NSMutableDictionary dictionary];
        NSMutableArray<NSString*> *sortedKeys = [NSMutableArray array];
        for(int i=0;i<4;i++) {
            int size = 1 << (9 + i); // Start at 512px
            
            UIImage* rescaled = scaleImage(image, CGSizeMake(size, size));
            NSData* rescaledData = UIImageJPEGRepresentation(rescaled, 0.95f); // Decent Quality
            
            if(rescaledData.length > data.length) {
                break;
            }
            else {
                NSString* size = friendlyFileSizeString(rescaledData.length);
                NSString* key = [NSString stringWithFormat:@"(%d x %d) %@", (int)rescaled.size.width, (int)rescaled.size.height, size];
                [resized setValue:rescaledData forKey:key];
                [sortedKeys addObject:key];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self promptForLargeImageRescaleChoice:suggestedFilename image:image data:data resized:resized sortedKeys:sortedKeys];
        });
    });
}

- (void)promptForLargeImageRescaleChoice:(NSString*)suggestedFilename image:(UIImage*)image
       data:(NSData*)data
    resized:(NSDictionary<NSString*, NSData*> *)resized
 sortedKeys:(NSArray<NSString*>*)sortedKeys {
    [SVProgressHUD dismiss];
    
    NSString* message = resized.count > 0 ? @"This is a rather large image which could negatively affect the performance of Strongbox, and significantly slow down network synchronisation times. Would you like to rescale this image to one of the streamlined options below?" :
    @"This is a rather large image which could negatively affect the performance of Strongbox, and significantly slow down network synchronisation times. Is there a smaller version you could use?";
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:resized.count > 0 ? @"Rescale Large Image?" : @"Use Large Image?"
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    if(resized.count > 0) {
        for (NSString* key in sortedKeys) {
            UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:key
                                                                    style:UIAlertActionStyleDefault
                                                                  handler:^(UIAlertAction *a) {
                                                                      [self addAttachmentNoWarn:suggestedFilename data:resized[key]];
                                                                  }];
            
            [alertController addAction:defaultAction];
        }
    }
    
    NSString* size = friendlyFileSizeString(data.length);
    UIAlertAction *originalAction = [UIAlertAction actionWithTitle:[NSString stringWithFormat:resized.count > 0 ? @"Original (%d x %d) %@" : @"Use Anyway (%d x %d) %@", (int)image.size.width, (int)image.size.height, size]
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction *a) {
                                                               [self addAttachmentNoWarn:suggestedFilename data:data];
                                                           }];
    [alertController addAction:originalAction];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *a) { }];
    [alertController addAction:cancelAction];
    
    [self.parentViewController presentViewController:alertController animated:YES completion:nil];
}

- (void)addAttachmentNoWarn:(NSString*)suggestedFilename data:(NSData*)data {
    Alerts *x = [[Alerts alloc] initWithTitle:@"Filename" message:@"Enter a filename for this item"];

    [x OkCancelWithTextFieldNotEmpty:self.parentViewController
                       textFieldText:suggestedFilename
                          completion:^(NSString *text, BOOL response) {
                              if(response) {
                                  if([self.usedFilenames containsObject:trim(text)]) {
                                      [Alerts warn:self.parentViewController
                                             title:@"Filename in Use"
                                           message:@"This filename is already in use. Please enter a different name." completion:^{
                                          [self addAttachmentNoWarn:suggestedFilename data:data];
                                      }];
                                  }
                                  else {
                                      if(self.onAdd) {
                                          UiAttachment* attachment = [[UiAttachment alloc] initWithFilename:text data:data];
                                          
                                          NSLog(@"Adding Attachment: [%@]", attachment);
                                          
                                          self.onAdd(attachment);
                                      }
                                  }
                              }
                          }];
}


@end
