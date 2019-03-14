//
//  NodeIconHelper.m
//  Strongbox
//
//  Created by Mark on 12/03/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "MacNodeIconHelper.h"
#import "ViewModel.h"
#import "Utils.h"
#import "KeePassPredefinedIcons.h"

static NSImage* kFolderImage;
//static NSImage* kStrongBox256Image;
static NSImage* kSmallYellowFolderImage;
static NSImage* kSmallLockImage;
//static NSImage* kDefaultAttachmentIcon;

@implementation MacNodeIconHelper

+ (void)initialize {
    if(self == [MacNodeIconHelper class]) {
        kFolderImage = [NSImage imageNamed:@"blue-folder-cropped-256"];
//        kStrongBox256Image = [NSImage imageNamed:@"StrongBox-256x256"];
        kSmallYellowFolderImage = [NSImage imageNamed:@"Places-folder-yellow-icon-32"];
        kSmallLockImage = [NSImage imageNamed:@"lock-48"];
//        kDefaultAttachmentIcon = [NSImage imageNamed:@"document_empty_64"];
    }
}

+ (NSImage * )getIconForNode:(ViewModel*)model vm:(Node *)vm large:(BOOL)large {
    NSImage* ret;
    
    if(model.format == kPasswordSafe) {
        if(!large) {
            ret = vm.isGroup ? kSmallYellowFolderImage : kSmallLockImage;
        }
        else {
            ret = vm.isGroup ? kFolderImage : kSmallLockImage;
        }
    }
    else {
        ret = vm.isGroup ? KeePassPredefinedIcons.icons[48] : KeePassPredefinedIcons.icons[0];
    }
    
    // KeePass Specials
    
    if(vm.customIconUuid) {
        NSData* data = model.customIcons[vm.customIconUuid];
        
        if(data) {
            NSImage* img = [[NSImage alloc] initWithData:data]; // FUTURE: Cache
            if(img) {
                NSImage *resized = scaleImage(img, CGSizeMake(48, 48)); // FUTURE: Scale up if large? THis is only used on details pane
                return resized;
            }
        }
    }
    else if(vm.iconId && vm.iconId.intValue >= 0 && vm.iconId.intValue < KeePassPredefinedIcons.icons.count) {
        ret = KeePassPredefinedIcons.icons[vm.iconId.intValue];
    }
    
    return ret;
}

@end
