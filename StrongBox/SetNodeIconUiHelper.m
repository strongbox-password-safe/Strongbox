//
//  SetNodeIconUiHelper.m
//  Strongbox-iOS
//
//  Created by Mark on 23/02/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "SetNodeIconUiHelper.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "Utils.h"
#import "SVProgressHUD.h"
#import "Alerts.h"
#import "IconsCollectionViewController.h"
#import "FavIconManager.h"
#import "FavIconBulkViewController.h"
#import "AppPreferences.h"
#import "NSString+Extensions.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface SetNodeIconUiHelper () <UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIDocumentPickerDelegate>

@property UIViewController *viewController;
@property (copy) ChangeIconCompletionBlock completionBlock;
@property Model* model;

@end

@implementation SetNodeIconUiHelper

- (void)changeIcon:(UIViewController *)viewController
             model:(Model*)model
              node:(Node *)node
       urlOverride:(NSString *)urlOverride
            format:(DatabaseFormat)format
    keePassIconSet:(KeePassIconSet)keePassIconSet
        completion:(ChangeIconCompletionBlock)completion {
    self.model = model;
    self.viewController = viewController;
    self.completionBlock = completion;
    
    if(format == kPasswordSafe) {
        slog(@"Should not be calling this if safe is Password Safe!!");
        self.completionBlock(NO, NO, nil);
        return;
    }
    if(format == kKeePass1) {
        [self presentKeePassAndDatabaseIconSets:keePassIconSet];
    }
    else {
        BOOL favIconPossible = node ? (node.isGroup || node.fields.url.urlExtendedParse != nil) : [self smartDetermineUrlFromHint:urlOverride] != nil;

        if (favIconPossible && !AppPreferences.sharedInstance.disableFavIconFeature) {
            UIAlertController *alertController =
            [UIAlertController alertControllerWithTitle:
             NSLocalizedString(@"set_icon_vc_select_icon_source_title", @"Select Icon Source")
                                                message:
             NSLocalizedString(@"set_icon_vc_select_icon_source_message", @"Select the source of the icon you would like to use for this entry")
                                         preferredStyle:UIAlertControllerStyleAlert];
            
            
            
            
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
            
            UIAlertAction *fourthAction = nil;
            
            if(node && node.isGroup) {
                fourthAction = [UIAlertAction actionWithTitle:AppPreferences.sharedInstance.isPro ?
                                          NSLocalizedString(@"set_icon_vc_icon_source_download_favicons", @"Download FavIcons") :
                                          NSLocalizedString(@"set_icon_vc_icon_source_download_favicons_pro_only", @"Download FavIcons (Pro Only)")
                                         style:UIAlertActionStyleDefault
                                       handler:^(UIAlertAction *a) {
                    [self onDownloadFavIcons:viewController node:node urlOverride:urlOverride completion:completion];
                }];
            }
            else {
                fourthAction = [UIAlertAction actionWithTitle:AppPreferences.sharedInstance.isPro ?
                                          NSLocalizedString(@"set_icon_vc_icon_source_download_favicon", @"Download FavIcon") :
                                          NSLocalizedString(@"set_icon_vc_icon_source_download_favicon_pro_only", @"Download FavIcon (Pro Only)")
                                         style:UIAlertActionStyleDefault
                                       handler:^(UIAlertAction *a) {
                    [self onDownloadFavIcons:viewController node:node urlOverride:urlOverride completion:completion];
                }];
            }
            
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"generic_cancel", @"Cancel")
                                                                   style:UIAlertActionStyleCancel
                                                                 handler:^(UIAlertAction *a) { self.completionBlock(NO, NO,  nil); }];
            
            fourthAction.enabled = AppPreferences.sharedInstance.isPro;
            
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
                       self.completionBlock(NO, NO, nil); 
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
                   completion:^(BOOL go, NSDictionary<NSUUID *,NodeIcon *> * _Nullable selectedFavIcons) {
            [self completeDownloadFavIcons:go isGroup:YES selectedFavIcons:selectedFavIcons completion:completion];
        }];
    }
    else {
        [self downloadFavIcon:viewController
                        nodes:@[node]
                  urlOverride:urlOverride
                   completion:^(BOOL go, NSDictionary<NSUUID *,NodeIcon *> * _Nullable selectedFavIcons) {
            [self completeDownloadFavIcons:go isGroup:NO selectedFavIcons:selectedFavIcons completion:completion];
        }];
    }
}

- (void)downloadFavIcon:(UIViewController*)presentingVc
                  nodes:(NSArray<Node*>*)nodes
            urlOverride:(NSString*)urlOverride
             completion:(FavIconBulkDoneBlock)completion {
    if (urlOverride) {
        [FavIconBulkViewController presentModal:presentingVc
                                          model:self.model
                                           node:nodes.firstObject
                                    urlOverride:urlOverride
                                         onDone:^(BOOL go, NSDictionary<NSUUID *,NodeIcon *> * _Nullable selectedFavIcons) {
            [presentingVc dismissViewControllerAnimated:YES completion:nil];
            completion(go, selectedFavIcons);
        }];
    }
    else {
        [FavIconBulkViewController presentModal:presentingVc
                                          model:self.model
                                          nodes:nodes
                                         onDone:^(BOOL go, NSDictionary<NSUUID *,NodeIcon *> * _Nullable selectedFavIcons) {
            [presentingVc dismissViewControllerAnimated:YES completion:nil];
            completion(go, selectedFavIcons);
        }];
    }
}

- (void)completeDownloadFavIcons:(BOOL)go 
                         isGroup:(BOOL)isGroup
                selectedFavIcons:(NSDictionary<NSUUID *, NodeIcon *> * _Nullable)selectedFavIcons
                      completion:(ChangeIconCompletionBlock)completion {
    NSMutableDictionary<NSUUID*, NodeIcon*>* ret = NSMutableDictionary.dictionary;
    
    if (go) {
        for (NSUUID* nodeUuidKey in selectedFavIcons) {
            NodeIcon* icon = selectedFavIcons[nodeUuidKey];
            if ( icon ) {
                ret[nodeUuidKey] = icon;
            }
        }
    }
    
    completion(go, isGroup, ret);
}

- (void)expressDownloadBestFavIcon:(NSString *)urlOverride 
                        completion:(void (^)(NodeIcon * _Nullable))completion {
    NSURL* url = [self smartDetermineUrlFromHint:urlOverride];
    
    if (url) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD showWithStatus:NSLocalizedString(@"set_icon_vc_progress_downloading_favicon", @"Downloading FavIcon")];
            slog(@"attempting to download favicon for: [%@]", url);

            [FavIconManager.sharedInstance downloadPreferred:url
                                                     options:FavIconDownloadOptions.express
                                                  completion:^(NodeIcon * _Nullable image) {
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
    NSURL* url = urlHint.urlExtendedParse;
    
    if(urlHint.length > 0) {
        NSURLComponents *components = [NSURLComponents componentsWithString:urlHint];
        slog(@"scheme = [%@],user = [%@],password = [%@],host = [%@],port = [%@],path = [%@],query = [%@],fragment = [%@]",
              components.scheme,
              components.user,
              components.password,
              components.host,
              components.port,
              components.path,
              components.query,
              components.fragment);
        
        if(!components.scheme.length) { 
            NSURLComponents* newComponents = [[NSURLComponents alloc] init];
            newComponents.scheme = @"http";
            NSArray* comp = [urlHint componentsSeparatedByString:@"/"];
            NSString* host = comp[0];
            if(![host containsString:@"."]) { 
                host = [host stringByAppendingString:@".com"];
            }
            
            newComponents.host = host;
            url = newComponents.URL;
        }
        else if (![components.scheme hasPrefix:@"http"]) { 
            NSURLComponents* newComponents = [[NSURLComponents alloc] init];
            newComponents.scheme = @"http";
            newComponents.host = components.host;
            url = newComponents.URL;
        }
        else { 
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
    vc.predefinedKeePassIconSet = iconSet;
    vc.iconPool = self.customIcons;
    vc.modalPresentationStyle = UIModalPresentationFormSheet;
    
    __weak SetNodeIconUiHelper* weakSelf = self;
    __weak IconsCollectionViewController* weakVc = vc;
    vc.onDone = ^(BOOL response, NodeIcon * _Nullable icon) {
        [weakVc.presentingViewController dismissViewControllerAnimated:YES completion:^{
            if(response) {
                weakSelf.completionBlock(YES, NO, icon ? @{ NSUUID.UUID : icon } : nil); 
            }
            else {
                weakSelf.completionBlock(NO, NO, nil);
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
        self.completionBlock(NO, NO, nil);
        return;
    }
    
    vc.mediaTypes = @[(NSString*)kUTTypeImage];
    vc.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    
    [self.viewController presentViewController:vc animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    __weak SetNodeIconUiHelper* weakSelf = self;

    [picker dismissViewControllerAnimated:YES completion:^{
         [weakSelf onDonePickingCustomIcon:info];
     }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    __weak SetNodeIconUiHelper* weakSelf = self;
    
    [picker dismissViewControllerAnimated:YES completion:^{
        weakSelf.completionBlock(NO, NO, nil);
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
                slog(@"Error: %@", error);
                [Alerts error:self.viewController
                        title:NSLocalizedString(@"set_icon_vc_error_reading_image", @"Error Reading Image")
                        error:error];
                self.completionBlock(NO, NO, nil);
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
        
        if(image.size.height > kMaxRecommendedCustomIconDimension || image.size.width > kMaxRecommendedCustomIconDimension) {
            UIImage* rescaled = scaleImage(image, CGSizeMake(kMaxRecommendedCustomIconDimension, kMaxRecommendedCustomIconDimension));
            NSData* rescaledData = UIImagePNGRepresentation(rescaled);
            
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD dismiss];
                
                if(dataOriginal.length > rescaledData.length) {
                    NSUInteger saving = dataOriginal.length - rescaledData.length;
                    NSString* savingString = friendlyFileSizeString(saving);
                    NSString* message = [NSString stringWithFormat:
                                         NSLocalizedString(@"set_icon_vc_prompt_rescale_image_message_fmt", @"This is a rather large image (%@x%@), would you like to rescale it to a maximum dimension of %@ pixels for a file size saving of roughly %@"), @((int)image.size.width), @((int)image.size.height), @(kMaxRecommendedCustomIconDimension), savingString];
                    
                    [Alerts yesNo:self.viewController
                            title:NSLocalizedString(@"set_icon_vc_prompt_rescale_image_title", @"Large Custom Icon Image, Rescale?")
                          message:message
                           action:^(BOOL response) {
                        UIImage* foo = response ? rescaled : image;
                        NSData* bar = UIImagePNGRepresentation(foo);
                        self.completionBlock(YES, NO, @{ NSUUID.UUID : [NodeIcon withCustom:bar] });
                    }];
                }
                else {
                    UIImage* foo = image;
                    NSData* bar = UIImagePNGRepresentation(foo);
                    self.completionBlock(YES, NO, @{ NSUUID.UUID : [NodeIcon withCustom:bar] });
                }
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD dismiss];
                UIImage* foo = image;
                NSData* bar = UIImagePNGRepresentation(foo);

                self.completionBlock(YES, NO, @{ NSUUID.UUID : [NodeIcon withCustom:bar] } ); 
            });
        }
    });
}

- (void)presentFiles {
    UTType* type = [UTType typeWithIdentifier:(NSString*)kUTTypeItem];
    UIDocumentPickerViewController *vc = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[type]];
    

    vc.delegate = self;
    vc.modalPresentationStyle = UIModalPresentationFormSheet;
    
    [self.viewController presentViewController:vc animated:YES completion:nil];
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
        
        [Alerts error:self.viewController
                title:NSLocalizedString(@"set_icon_vc_error_reading_image", @"Error Reading Image")
                error:error];

        return;
    }

    [self analyzeCustomIconAndSet:data];
}
#pragma GCC diagnostic pop

@end
