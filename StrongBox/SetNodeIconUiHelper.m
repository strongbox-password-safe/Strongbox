//
//  SetNodeIconUiHelper.m
//  Strongbox-iOS
//
//  Created by Mark on 23/02/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SetNodeIconUiHelper.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "Utils.h"
#import "SVProgressHUD.h"
#import "Alerts.h"
#import "IconsCollectionViewController.h"
#import "Settings.h"
#import "FavIconManager.h"
#import "FavIconBulkViewController.h"

@interface SetNodeIconUiHelper () <UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIDocumentPickerDelegate>

@property UIViewController *viewController;
@property ChangeIconCompletionBlock completionBlock;

@end

@implementation SetNodeIconUiHelper

- (void)changeIcon:(UIViewController *)viewController
              node:(Node *)node
       urlOverride:(NSString *)urlOverride
            format:(DatabaseFormat)format
    keePassIconSet:(KeePassIconSet)keePassIconSet
        completion:(ChangeIconCompletionBlock)completion {
    self.viewController = viewController;
    self.completionBlock = completion;
    
    if(format == kPasswordSafe) {
        NSLog(@"Should not be calling this if safe is Password Safe!!");
        self.completionBlock(NO, nil, nil, NO, nil);
        return;
    }
    if(format == kKeePass1) {
        [self presentKeePassAndDatabaseIconSets:keePassIconSet];
    }
    else {
        BOOL favIconPossible = node ? (node.isGroup || [NSURL URLWithString:node.fields.url] != nil) : [self smartDetermineUrlFromHint:urlOverride] != nil;
        
        if (favIconPossible) {
            UIAlertController *alertController =
            [UIAlertController alertControllerWithTitle:
             NSLocalizedString(@"set_icon_vc_select_icon_source_title", @"Select Icon Source")
                                                message:
             NSLocalizedString(@"set_icon_vc_select_icon_source_message", @"Select the source of the icon you would like to use for this entry")
                                         preferredStyle:UIAlertControllerStyleAlert];
            
            // this is the center of the screen currently but it can be any point in the view
            
            
            UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:
                                            NSLocalizedString(@"set_icon_vc_icon_source_keepass_set", @"KeePass & Database Icon Set")
                                                                    style:UIAlertActionStyleDefault
                                                                  handler:^(UIAlertAction *a) { [self presentKeePassAndDatabaseIconSets:keePassIconSet]; }];
            
            UIAlertAction *secondAction = [UIAlertAction actionWithTitle:
                                           NSLocalizedString(@"add_attachment_vc_prompt_source_option_files", @"Files")
                                                                   style:UIAlertActionStyleDefault
                                                                 handler:^(UIAlertAction *a) { [self presentFiles ]; }];

            UIAlertAction *thirdAction = [UIAlertAction actionWithTitle:
                                           NSLocalizedString(@"set_icon_vc_icon_source_media_libary", @"Media Library")
                                                                   style:UIAlertActionStyleDefault
                                                                 handler:^(UIAlertAction *a) { [self presentCustomIconImagePicker]; }];
            
            UIAlertAction *fourthAction;
            
            if(node && node.isGroup) {
                fourthAction = [UIAlertAction actionWithTitle:Settings.sharedInstance.isProOrFreeTrial ?
                                          NSLocalizedString(@"set_icon_vc_icon_source_download_favicons", @"Download FavIcons") :
                                          NSLocalizedString(@"set_icon_vc_icon_source_download_favicons_pro_only", @"Download FavIcons (Pro Only)")
                                         style:UIAlertActionStyleDefault
                                       handler:^(UIAlertAction *a) {
                    [self onDownloadFavIcons:viewController node:node urlOverride:urlOverride completion:completion];
                }];
            }
            else {
                fourthAction = [UIAlertAction actionWithTitle:Settings.sharedInstance.isProOrFreeTrial ?
                                          NSLocalizedString(@"set_icon_vc_icon_source_download_favicon", @"Download FavIcon") :
                                          NSLocalizedString(@"set_icon_vc_icon_source_download_favicon_pro_only", @"Download FavIcon (Pro Only)")
                                         style:UIAlertActionStyleDefault
                                       handler:^(UIAlertAction *a) {
                    [self onDownloadFavIcons:viewController node:node urlOverride:urlOverride completion:completion];
                }];
            }
            
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"generic_cancel", @"Cancel")
                                                                   style:UIAlertActionStyleCancel
                                                                 handler:^(UIAlertAction *a) { self.completionBlock(NO, nil, nil, NO,  nil); }];
            
            fourthAction.enabled = Settings.sharedInstance.isProOrFreeTrial;
            
            [alertController addAction:defaultAction];
            [alertController addAction:secondAction];
            [alertController addAction:thirdAction];
            [alertController addAction:fourthAction];
            [alertController addAction:cancelAction];
            
            [self.viewController presentViewController:alertController animated:YES completion:nil];
        }
        else {
            [Alerts threeOptions:viewController
                           title:NSLocalizedString(@"set_icon_vc_select_icon_source_title", @"Select Icon Source")
                         message:NSLocalizedString(@"set_icon_vc_select_icon_source_message", @"Select the source of the icon you would like to use for this entry")
               defaultButtonText:NSLocalizedString(@"set_icon_vc_icon_source_keepass_set", @"KeePass & Database Icon Set")
                secondButtonText:NSLocalizedString(@"set_icon_vc_icon_source_media_libary", @"Media Library")
                 thirdButtonText:NSLocalizedString(@"generic_cancel", @"Cancel")
                          action:^(int response) {
                   if(response == 0) {
                       [self presentKeePassAndDatabaseIconSets:keePassIconSet];
                   }
                   else if(response == 1) {
                       [self presentCustomIconImagePicker];
                   }
                   else {
                       self.completionBlock(NO, nil, nil,  NO, nil); // Cancelled
                   }}];
        }
    }
}

- (void)onDownloadFavIcons:(UIViewController *)viewController
                      node:(Node* _Nonnull)node
               urlOverride:(NSString*)urlOverride
                completion:(ChangeIconCompletionBlock)completion {
    if(node.isGroup) {
        [self downloadFavIcon:viewController
                        nodes:node.allChildRecords
                      urlOverride:urlOverride
                   completion:^(BOOL go, NSDictionary<NSUUID *,UIImage *> * _Nullable selectedFavIcons) {
            completion(go, nil, nil, YES, selectedFavIcons);
        }];
    }
    else {
        [self downloadFavIcon:viewController
                        nodes:@[node]
                  urlOverride:urlOverride
                   completion:^(BOOL go, NSDictionary<NSUUID *,UIImage *> * _Nullable selectedFavIcons) {
            completion(go, nil, nil, NO, selectedFavIcons);
        }];
    }
}

- (void)downloadFavIcon:(UIViewController*)presentingVc
                  nodes:(NSArray<Node*>*)nodes
            urlOverride:(NSString*)urlOverride
             completion:(FavIconBulkDoneBlock)completion {
    if (urlOverride) {
        [FavIconBulkViewController presentModal:presentingVc node:nodes.firstObject urlOverride:urlOverride
                                         onDone:^(BOOL go, NSDictionary<NSUUID*,UIImage *> * _Nullable selectedFavIcons) {
            [presentingVc dismissViewControllerAnimated:YES completion:nil];
            completion(go, selectedFavIcons);
        }];
    }
    else {
        [FavIconBulkViewController presentModal:presentingVc nodes:nodes onDone:^(BOOL go, NSDictionary<NSUUID*,UIImage *> * _Nullable selectedFavIcons) {
            [presentingVc dismissViewControllerAnimated:YES completion:nil];
            completion(go, selectedFavIcons);
        }];
    }
}

- (void)expressDownloadBestFavIcon:(NSString*)urlOverride completion:(void (^)(UIImage * _Nullable))completion {
    NSURL* url = [self smartDetermineUrlFromHint:urlOverride];
    
    if (url) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD showWithStatus:NSLocalizedString(@"set_icon_vc_progress_downloading_favicon", @"Downloading FavIcon")];
            NSLog(@"attempting to download favicon for: [%@]", url);

            [FavIconManager.sharedInstance downloadPreferred:url
                                                     options:FavIconDownloadOptions.express
                                                  completion:^(UIImage * _Nullable image) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [SVProgressHUD dismiss];
                    completion(image);
                });
            }];
        });
    }
    else {
        completion(nil);
    }
}

- (NSURL*)smartDetermineUrlFromHint:(NSString*)urlHint {
    NSURL* url = [NSURL URLWithString:urlHint];
    
    if(urlHint.length > 0) {
        NSURLComponents *components = [NSURLComponents componentsWithString:urlHint];
        NSLog(@"scheme = [%@],user = [%@],password = [%@],host = [%@],port = [%@],path = [%@],query = [%@],fragment = [%@]",
              components.scheme,
              components.user,
              components.password,
              components.host,
              components.port,
              components.path,
              components.query,
              components.fragment);
        
        if(!components.scheme.length) { // facebook.com/whatever.php or just even Facebook!
            NSURLComponents* newComponents = [[NSURLComponents alloc] init];
            newComponents.scheme = @"http";
            NSArray* comp = [urlHint componentsSeparatedByString:@"/"];
            NSString* host = comp[0];
            if(![host containsString:@"."]) { // maybe just Facebook
                host = [host stringByAppendingString:@".com"];
            }
            
            newComponents.host = host;
            url = newComponents.URL;
        }
        else if (![components.scheme hasPrefix:@"http"]) { // ftp://facebook.com
            NSURLComponents* newComponents = [[NSURLComponents alloc] init];
            newComponents.scheme = @"http";
            newComponents.host = components.host;
            url = newComponents.URL;
        }
        else { // http://facebook.com/whatever.php - strip the path, just use the host
            NSURLComponents* newComponents = [[NSURLComponents alloc] init];
            newComponents.scheme = components.scheme;
            newComponents.host = components.host;
            url = newComponents.URL;
        }
    }
    
    return url;
}

- (void)presentKeePassAndDatabaseIconSets:(KeePassIconSet)iconSet {
    IconsCollectionViewController* vc = [[IconsCollectionViewController alloc] init];
    vc.iconSet = iconSet;
    vc.customIcons = self.customIcons;
    vc.modalPresentationStyle = UIModalPresentationFormSheet;
    
    vc.onDone = ^(BOOL response, NSInteger selectedIndex, NSUUID * _Nullable selectedCustomIconId) {
        [self.viewController dismissViewControllerAnimated:YES completion:^{
            if(response) {
                self.completionBlock(YES, @(selectedIndex), selectedCustomIconId, NO, nil);
            }
            else {
                self.completionBlock(NO, nil, nil, NO, nil);
            }
        }];
    };
    
    [self.viewController presentViewController:vc animated:YES completion:nil];
}

- (void)presentCustomIconImagePicker {
    UIImagePickerController *vc = [[UIImagePickerController alloc] init];
    vc.videoQuality = UIImagePickerControllerQualityTypeHigh;
    vc.delegate = self;
    vc.modalPresentationStyle = UIModalPresentationFormSheet;
    
    BOOL available = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary];
    
    if(!available) {
        [Alerts info:self.viewController
               title:NSLocalizedString(@"set_icon_vc_image_src_unavailable_title", @"Image Source Unavailable")
             message:NSLocalizedString(@"set_icon_vc_image_src_photos_unavailable_message", @"Could not access photos source.")];
        self.completionBlock(NO, nil, nil, NO, nil);
        return;
    }
    
    vc.mediaTypes = @[(NSString*)kUTTypeImage];
    vc.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    
    [self.viewController presentViewController:vc animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    [picker dismissViewControllerAnimated:YES completion:^
     {
         [self onDonePickingCustomIcon:info];
     }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:^
     {
         self.completionBlock(NO, nil, nil, NO, nil);
     }];
}

- (void)onDonePickingCustomIcon:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    [SVProgressHUD showWithStatus:NSLocalizedString(@"set_icon_vc_progress_reading_data", @"Reading Data...")];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
        NSError* error;
        NSData* data = [Utils getImageDataFromPickedImage:info error:&error];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD dismiss];
            if(!data) {
                NSLog(@"Error: %@", error);
                [Alerts error:self.viewController
                        title:NSLocalizedString(@"set_icon_vc_error_reading_image", @"Error Reading Image")
                        error:error];
                self.completionBlock(NO, nil, nil, NO, nil);
            }
            else {
                [self analyzeCustomIconAndSet:data];
            }
        });
    });
}

static const int kMaxRecommendedCustomIconDimension = 256;

- (void)analyzeCustomIconAndSet:(NSData*)data {
    [SVProgressHUD showWithStatus:NSLocalizedString(@"set_icon_vc_progress_analyzing_image", @"Analyzing Image...")];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
        UIImage* image = [UIImage imageWithData:data];
        NSData* dataOriginal = UIImagePNGRepresentation(image);
        //NSLog(@"before: %f - %f - %lu", image.size.width, image.size.height, (unsigned long)dataOriginal.length);
        if(image.size.height > kMaxRecommendedCustomIconDimension || image.size.width > kMaxRecommendedCustomIconDimension) {
            UIImage* rescaled = scaleImage(image, CGSizeMake(kMaxRecommendedCustomIconDimension, kMaxRecommendedCustomIconDimension));
            NSData* rescaledData = UIImagePNGRepresentation(rescaled);
            //NSLog(@"after: %f - %f - %lu", rescaled.size.width, rescaled.size.height, (unsigned long)rescaledData.length);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD dismiss];
                
                if(dataOriginal.length > rescaledData.length) {
                    NSUInteger saving = dataOriginal.length - rescaledData.length;
                    NSString* savingString = friendlyFileSizeString(saving);
                    NSString* message = [NSString stringWithFormat:
                                         NSLocalizedString(@"set_icon_vc_prompt_rescale_image_message_fmt", @"This is a rather large image (%dx%d), would you like to rescale it to a maximum dimension of %d pixels for a file size saving of roughly %@"), (int)image.size.width, (int)image.size.height, kMaxRecommendedCustomIconDimension, savingString];
                    
                    [Alerts yesNo:self.viewController
                            title:NSLocalizedString(@"set_icon_vc_prompt_rescale_image_title", @"Large Custom Icon Image, Rescale?")
                          message:message
                           action:^(BOOL response) {
                        self.completionBlock(YES, nil, nil, NO, @{ NSUUID.UUID : response ? rescaled : image});
                    }];
                }
                else {
                    self.completionBlock(YES, nil, nil, NO, @{ NSUUID.UUID : image });
                }
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD dismiss];
                self.completionBlock(YES, nil, nil, NO, @{ NSUUID.UUID : image } ); // SO hacky - split entry functions up so we don't need to do this badness
            });
        }
    });
}

- (void)presentFiles {
    UIDocumentPickerViewController *vc = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[(NSString*)kUTTypeImage] inMode:UIDocumentPickerModeImport];
    vc.delegate = self;
    vc.modalPresentationStyle = UIModalPresentationFormSheet;
    
    [self.viewController presentViewController:vc animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSLog(@"didPickDocumentsAtURLs: %@", urls);
    
    NSURL* url = [urls objectAtIndex:0];
    NSError* error;
    NSData* data = [NSData dataWithContentsOfURL:url options:kNilOptions error:&error];
    
    if(!data) {
        NSLog(@"Error: %@", error);
        
        [Alerts error:self.viewController
                title:NSLocalizedString(@"set_icon_vc_error_reading_image", @"Error Reading Image")
                error:error];

        return;
    }

    [self analyzeCustomIconAndSet:data];
}

@end
