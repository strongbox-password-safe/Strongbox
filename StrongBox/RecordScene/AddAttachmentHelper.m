//
//  AddAttachmentHelper.m
//  Strongbox-iOS
//
//  Created by Mark on 25/04/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "AddAttachmentHelper.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "Alerts.h"
#import "Utils.h"
#import "SVProgressHUD.h"
#import "UIImage+FixOrientation.h"
#import "NSDate+Extensions.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

const int kMaxRecommendedAttachmentSize = 512 * 1024; 

@interface AddAttachmentHelper () <UIImagePickerControllerDelegate, UIDocumentPickerDelegate, UINavigationControllerDelegate>

@property UIViewController* parentViewController;
@property (nonatomic, copy) void (^onAdd)(NSString* filename, KeePassAttachmentAbstractionLayer* databaseAttachment);
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

- (void)beginAddAttachmentUi:(UIViewController *)vc
               usedFilenames:(NSSet<NSString *> *)usedFilenames
                       onAdd:(void (^)(NSString* filename, KeePassAttachmentAbstractionLayer* databaseAttachment))onAdd {
    self.parentViewController = vc;
    self.onAdd = onAdd;
    
    
    self.usedFilenames = usedFilenames;
    
    UIAlertController *alertController =
    [UIAlertController alertControllerWithTitle:NSLocalizedString(@"add_attachment_vc_prompt_title", @"Attachment Location")
                                        message:nil
                                 preferredStyle:UIAlertControllerStyleAlert];
    
    NSArray<NSString*>* buttonTitles =
    @[  NSLocalizedString(@"add_attachment_vc_prompt_source_option_photos", @"Photos"),
        NSLocalizedString(@"add_attachment_vc_prompt_source_option_camera", @"Camera"),
        NSLocalizedString(@"add_attachment_vc_prompt_source_option_files", @"Files")];
    
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
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"generic_cancel", @"Cancel")
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *a) {
                                                             [self onAddAttachmentLocationResponse:0];
                                                         }];
    [alertController addAction:cancelAction];
    
    alertController.popoverPresentationController.sourceView = self.parentViewController.view;
    [self.parentViewController presentViewController:alertController animated:YES completion:nil];
}

- (void)onAddAttachmentLocationResponse:(int)response {
    if(response == 3) {
        UTType* type = [UTType typeWithIdentifier:(NSString*)kUTTypeItem];
        UIDocumentPickerViewController *vc = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[type]];


        vc.delegate = self;
        vc.modalPresentationStyle = UIModalPresentationFormSheet;
        
        [self.parentViewController presentViewController:vc animated:YES completion:nil];
    }
    else if(response == 2 || response == 1) {
        UIImagePickerController *vc = [[UIImagePickerController alloc] init];
        vc.delegate = self;
        vc.videoQuality = UIImagePickerControllerQualityTypeHigh;
        vc.modalPresentationStyle = UIModalPresentationFormSheet;
        
        UIImagePickerControllerSourceType source = response == 1 ? UIImagePickerControllerSourceTypePhotoLibrary : UIImagePickerControllerSourceTypeCamera;
        
        BOOL available = [UIImagePickerController isSourceTypeAvailable:source];
        
        if(!available) {
            [Alerts info:self.parentViewController
                   title:NSLocalizedString(@"add_attachment_vc_error_source_unavailable_title", @"Source Unavailable")
                 message:response == 2 ?
                                           NSLocalizedString(@"add_attachment_vc_error_source_unavailable_camera", @"Strongbox could not access the camera. Does it have permission?") :
                                           NSLocalizedString(@"add_attachment_vc_error_source_unavailable_photos", @"Strongbox could not access photos. Does it have permission?")];
            return;
        }
        
        vc.mediaTypes = @[(NSString*)kUTTypeMovie, (NSString*)kUTTypeImage];
        vc.sourceType = source;
        
        [self.parentViewController presentViewController:vc animated:YES completion:nil];
    }
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    slog(@"didPickDocumentsAtURLs: %@", urls);
    
    NSURL* url = [urls objectAtIndex:0];

    
    
    if (! [url startAccessingSecurityScopedResource] ) {
        slog(@"🔴 Could not securely access URL!");
    }
    
    NSError* error;
    __block NSData *data;
    __block NSError *err;
    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] init];
    [coordinator coordinateReadingItemAtURL:url options:0 error:&error byAccessor:^(NSURL *newURL) {
        data = [NSData dataWithContentsOfURL:newURL options:NSDataReadingUncached error:&err];
    }];
    
    [url stopAccessingSecurityScopedResource];
    
    if(!data) {
        slog(@"Error: %@", error);
        [Alerts warn:self.parentViewController
               title:NSLocalizedString(@"add_attachment_vc_error_reading_title", @"Error Reading")
             message:NSLocalizedString(@"add_attachment_vc_error_reading_message", @"Could not read the data for this item.")];
        return;
    }
    
    NSString *filename = [url.absoluteString.lastPathComponent stringByRemovingPercentEncoding];
    [self addAttachment:filename data:data];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    slog(@"Image Pick did finish: [%@]", info);
    NSString* mediaType = [info objectForKey:UIImagePickerControllerMediaType];
    BOOL isImage = UTTypeConformsTo((__bridge CFStringRef)mediaType, kUTTypeImage) != 0;
    
    NSURL *url;
    NSData* data;
    NSString *suggestedFilename = @"image.png";

    if(isImage) {
        url =  [info objectForKey:UIImagePickerControllerImageURL];
        
        if(!url) {
            UIImage* image = [info objectForKey:UIImagePickerControllerOriginalImage];
            
            if(!image) {
                [Alerts warn:self.parentViewController
                       title:NSLocalizedString(@"add_attachment_vc_error_reading_title", @"Error Reading")
                     message:NSLocalizedString(@"add_attachment_vc_error_reading_message", @"Could not read the data for this item.")];
                return;
            }
            
            UIImage* fixed = [image fixOrientation];
            
            data = UIImagePNGRepresentation(fixed);
            suggestedFilename = [NSString stringWithFormat:@"%@.png", NSDate.date.iso8601DateString];
        }
    }
    else {
        url =  [info objectForKey:UIImagePickerControllerMediaURL];
    }
    
    NSError* error;
    if(url) {
        data = [NSData dataWithContentsOfURL:url options:kNilOptions error:&error];
        suggestedFilename = [url.absoluteString.lastPathComponent stringByRemovingPercentEncoding];
    }
    
    if(!data) {
        slog(@"Error: %@", error);
        
        [picker dismissViewControllerAnimated:YES completion:^{
            [Alerts warn:self.parentViewController
                   title:NSLocalizedString(@"add_attachment_vc_error_reading_title", @"Error Reading")
                 message:NSLocalizedString(@"add_attachment_vc_error_reading_message", @"Could not read the data for this item.")];
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
            NSString* message = [NSString stringWithFormat:NSLocalizedString(@"add_attachment_vc_large_file_message_fmt", @"This is quite a large file (%@), and could significantly affect the performance of Strongbox and slow down syncs across networks. Is there a smaller version you could use?\n\nContinue adding this attachment anyway?"), friendlyFileSizeString(data.length)];

            [Alerts yesNo:self.parentViewController
                    title:NSLocalizedString(@"add_attachment_vc_large_file_title", @"Large Attachment")
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
    [SVProgressHUD showWithStatus:NSLocalizedString(@"add_attachment_vc_large_file_analyzing_progress_title", @"Analyzing Image...")];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
        NSMutableDictionary<NSString*, NSData*> *resized = [NSMutableDictionary dictionary];
        NSMutableArray<NSString*> *sortedKeys = [NSMutableArray array];
        for(int i=0;i<4;i++) {
            int size = 1 << (9 + i); 
            
            UIImage* rescaled = scaleImage(image, CGSizeMake(size, size));
            NSData* rescaledData = UIImageJPEGRepresentation(rescaled, 0.95f); 
            
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

- (void)promptForLargeImageRescaleChoice:(NSString*)suggestedFilename
                                   image:(UIImage*)image
                                    data:(NSData*)data
                                 resized:(NSDictionary<NSString*, NSData*> *)resized
                              sortedKeys:(NSArray<NSString*>*)sortedKeys {
    [SVProgressHUD dismiss];
    
    NSString* message = resized.count > 0 ?
    NSLocalizedString(@"add_attachment_vc_large_image_message_rescale",  @"This is a rather large image which could negatively affect the performance of Strongbox, and significantly slow down network synchronisation times. Would you like to rescale this image to one of the streamlined options below?") :
    NSLocalizedString(@"add_attachment_vc_large_image_message", @"This is a rather large image which could negatively affect the performance of Strongbox, and significantly slow down network synchronisation times. Is there a smaller version you could use?");
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:resized.count > 0 ?
                                          NSLocalizedString(@"add_attachment_vc_large_image_prompt_rescale_title", @"Rescale Large Image?") :
                                          NSLocalizedString(@"add_attachment_vc_large_image_prompt_use", @"Use Large Image?")
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
    UIAlertAction *originalAction =
        [UIAlertAction actionWithTitle:[NSString stringWithFormat:resized.count > 0 ?
            NSLocalizedString(@"add_attachment_vc_large_image_prompt_option_original_size_fmt2", @"Original (%@ x %@) %@") :
            NSLocalizedString(@"add_attachment_vc_large_image_prompt_option_use_anyway_size_fmt2", @"Use Anyway (%@ x %@) %@"),
                                                                    @((int)image.size.width), @((int)image.size.height), size]
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction *a) {
                                                               [self addAttachmentNoWarn:suggestedFilename data:data];
                                                           }];
    [alertController addAction:originalAction];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:
                                   NSLocalizedString(@"generic_cancel", @"Cancel")
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *a) { }];
    [alertController addAction:cancelAction];
    
    [self.parentViewController presentViewController:alertController animated:YES completion:nil];
}

- (void)addAttachmentNoWarn:(NSString*)suggestedFilename data:(NSData*)data {
    Alerts *x = [[Alerts alloc] initWithTitle:NSLocalizedString(@"add_attachment_vc_prompt_filename_title", @"Filename")
                                      message:NSLocalizedString(@"add_attachment_vc_prompt_filename_message", @"Enter a filename for this item")];

    [x OkCancelWithTextFieldNotEmpty:self.parentViewController
                       textFieldText:suggestedFilename
                          completion:^(NSString *text, BOOL response) {
                              if(response) {
                                  if([self.usedFilenames containsObject:trim(text)]) {
                                      [Alerts warn:self.parentViewController
                                             title:NSLocalizedString(@"add_attachment_vc_warn_filename_used_title", @"Filename in Use")
                                           message:NSLocalizedString(@"add_attachment_vc_warn_filename_used_message", @"This filename is already in use. Please enter a different name.")
                                        completion:^{
                                          [self addAttachmentNoWarn:suggestedFilename data:data];
                                      }];
                                  }
                                  else {
                                      if(self.onAdd) {
                                          NSInputStream* inputStream = [NSInputStream inputStreamWithData:data];
                                          KeePassAttachmentAbstractionLayer *dbAttachment = [[KeePassAttachmentAbstractionLayer alloc] initWithStream:inputStream length:data.length protectedInMemory:YES compressed:YES];
                                          
                                          slog(@"Adding Attachment: [%@]-[%@]", text, dbAttachment.digestHash);
                                          
                                          self.onAdd(text, dbAttachment);
                                      }
                                  }
                              }
                          }];
}

@end
