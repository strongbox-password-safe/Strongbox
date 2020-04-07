//
//  NodeIconHelper.m
//  Strongbox
//
//  Created by Mark on 12/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "NodeIconHelper.h"
#import "NSArray+Extensions.h"
#import "Utils.h"

static UIImage* kPwSafeFolderImage;
static UIImage* kPwSafeRecordImage;
static NSArray<UIImage*> *kKeePassIconSet;
static NSArray<UIImage*> *kKeePassiOS13SFIconSet;
static UIColor *kSandyFolderColor;

@implementation NodeIconHelper

+ (void)initialize {
    if(self == [NodeIconHelper class]) {
        kPwSafeFolderImage = [UIImage imageNamed:@"folder"];
        kPwSafeRecordImage = [UIImage imageNamed:@"document"];
        
        kKeePassIconSet = getKeePassIconSet();
        kKeePassiOS13SFIconSet = getKeePassiOS13SFIconSet();
        kSandyFolderColor = ColorFromRGB(0xFAB805);
    }
}

static NSArray<UIImage*>* getKeePassiOS13SFIconSet() {
    if (@available(iOS 13.0, *)) {
        NSArray<NSString*>* names = @[@"lock",
                                      @"globe",
                                      @"exclamationmark.triangle",
                                      @"hifispeaker",
                                      @"pin.circle.fill",
                                      @"message.circle.fill",
                                      @"cube.box.fill",
                                      @"square.and.pencil",
                                      @"exclamationmark.bubble.fill",
                                      @"creditcard",
                                      @"person.crop.square.fill",
                                      @"camera",
                                      @"antenna.radiowaves.left.and.right",
                                      @"square.stack.3d.up.fill",
                                      @"power",
                                      @"doc.text.viewfinder",
                                      @"star.circle",
                                      @"smallcircle.circle.fill",
                                      @"tv.fill",
                                      @"envelope.open.fill",
                                      @"gear",
                                      @"doc.on.clipboard",
                                      @"doc.plaintext",
                                      @"doc.richtext",
                                      @"bolt.circle.fill",
                                      @"envelope.badge.fill",
                                      @"desktopcomputer",
                                      @"phone.circle.fill",
                                      @"at",
                                      @"tv.circle",
                                      @"tv.circle.fill",
                                      @"printer",
                                      @"perspective",
                                      @"square.fill",
                                      @"wrench.fill",
                                      @"slider.horizontal.below.rectangle",
                                      @"selection.pin.in.out",
                                      @"percent",
                                      @"uiwindow.split.2x1",
                                      @"clock.fill",
                                      @"magnifyingglass.circle",
                                      @"hexagon.fill",
                                      @"memories",
                                      @"trash.circle.fill",
                                      @"mappin.circle.fill",
                                      @"clear.fill",
                                      @"questionmark.circle.fill",
                                      @"archivebox.fill",
                                      @"folder.fill",
                                      @"folder.fill.badge.person.crop",
                                      @"folder.circle.fill",
                                      @"lock.open.fill",
                                      @"lock.fill",
                                      @"checkmark.circle.fill",
                                      @"pencil",
                                      @"book.circle.fill",
                                      @"airplane",
                                      @"text.justify",
                                      @"person.badge.plus.fill",
                                      @"hammer.fill",
                                      @"house.fill",
                                      @"star.fill",
                                      @"tortoise.fill",
                                      @"flame.fill",
                                      @"burn",
                                      @"w.square.fill",
                                      @"dollarsign.circle.fill",
                                      @"signature",
                                      @"equal.square.fill"];
        
        return [names map:^id _Nonnull(NSString * _Nonnull obj, NSUInteger idx) {
            UIImage* img = [UIImage systemImageNamed:obj];
            return img ? img : [UIImage systemImageNamed:@"lock"];
        }];
    }
    else {
        return getKeePassIconSet();
    }
}

static NSArray<UIImage*>* getKeePassIconSet() {
    NSArray<NSString*>* names = @[@"C00_Password",
                                  @"C01_Package_Network",
                                  @"C02_MessageBox_Warning",
                                  @"C03_Server",
                                  @"C04_Klipper",
                                  @"C05_Edu_Languages",
                                  @"C06_KCMDF",
                                  @"C07_Kate",
                                  @"C08_Socket",
                                  @"C09_Identity",
                                  @"C10_Kontact",
                                  @"C11_Camera",
                                  @"C12_IRKickFlash",
                                  @"C13_KGPG_Key3",
                                  @"C14_Laptop_Power",
                                  @"C15_Scanner",
                                  @"C16_Mozilla_Firebird",
                                  @"C17_CDROM_Unmount",
                                  @"C18_Display",
                                  @"C19_Mail_Generic",
                                  @"C20_Misc",
                                  @"C21_KOrganizer",
                                  @"C22_ASCII",
                                  @"C23_Icons",
                                  @"C24_Connect_Established",
                                  @"C25_Folder_Mail",
                                  @"C26_FileSave",
                                  @"C27_NFS_Unmount",
                                  @"C28_Message",
                                  @"C29_KGPG_Term",
                                  @"C30_Konsole",
                                  @"C31_FilePrint",
                                  @"C32_FSView",
                                  @"C33_Run",
                                  @"C34_Configure",
                                  @"C35_KRFB",
                                  @"C36_Ark",
                                  @"C37_KPercentage",
                                  @"C38_Samba_Unmount",
                                  @"C39_History",
                                  @"C40_Mail_Find",
                                  @"C41_VectorGfx",
                                  @"C42_KCMMemory",
                                  @"C43_Trashcan_Full",
                                  @"C44_KNotes",
                                  @"C45_Cancel",
                                  @"C46_Help",
                                  @"C47_KPackage",
                                  @"C48_Folder",
                                  @"C49_Folder_Blue_Open",
                                  @"C50_Folder_Tar",
                                  @"C51_Decrypted",
                                  @"C52_Encrypted",
                                  @"C53_Apply",
                                  @"C54_Signature",
                                  @"C55_Thumbnail",
                                  @"C56_KAddressBook",
                                  @"C57_View_Text",
                                  @"C58_KGPG",
                                  @"C59_Package_Development",
                                  @"C60_KFM_Home",
                                  @"C61_Services",
                                  @"C62_Tux",
                                  @"C63_Feather",
                                  @"C64_Apple",
                                  @"C65_W",
                                  @"C66_Money",
                                  @"C67_Certificate",
                                  @"C68_Smartphone"];
    
    return [names map:^id _Nonnull(NSString * _Nonnull obj, NSUInteger idx) {
        return [UIImage imageNamed:obj];
    }];
}

+ (UIColor*)folderTintColor {
    return kSandyFolderColor;
}

+ (UIImage *)getIconForNode:(Node *)vm model:(id)model {
    return [NodeIconHelper getIconForNode:vm.isGroup
                           customIconUuid:vm.customIconUuid
                                   iconId:vm.iconId
                                    model:model];
}

+ (UIImage *)getIconForNode:(BOOL)isGroup
             customIconUuid:(NSUUID *)customIconUuid
                     iconId:(NSNumber *)iconId
                      model:(Model*)model {
    UIImage* ret;
    
    if(model.database.format == kPasswordSafe) {
        return isGroup ? kPwSafeFolderImage : kPwSafeRecordImage;
    }
    else {
        ret = isGroup ? kKeePassIconSet[48] : kKeePassIconSet[0];

        if(model.metadata.keePassIconSet == kKeePassIconSetSfSymbols) {
            if (@available(iOS 13.0, *)) {
                ret = isGroup ? kKeePassiOS13SFIconSet[48] : kKeePassiOS13SFIconSet[0];
            }
        }
    }
    
    // KeePass Specials
    
    if(customIconUuid) {
        ret = [NodeIconHelper getCustomIcon:customIconUuid customIcons:model.database.customIcons];
    }
    else if(iconId && iconId.intValue >= 0 && iconId.intValue < kKeePassIconSet.count) {
        ret = kKeePassIconSet[iconId.intValue];

        if(model.metadata.keePassIconSet == kKeePassIconSetSfSymbols) {
            if (@available(iOS 13.0, *)) {
                ret = kKeePassiOS13SFIconSet[iconId.intValue];
            }
        }
    }
    
    return ret;
}


+ (UIImage*)getCustomIcon:(NSUUID*)uuid customIcons:(NSDictionary<NSUUID*, NSData*>*)customIcons {
    NSData* data = customIcons[uuid];
    
    if(data) {
        //NSLog(@"Custom: [%@]", [data base64EncodedStringWithOptions:kNilOptions]);
        UIImage* img = [UIImage imageWithData:data];
        if(!img) {
            return nil;
        }
        
        if(img.size.height != 48 || img.size.width != 48) {
            return scaleImage(img, CGSizeMake(48, 48));
        }
        
        return img;
    }
    
    return nil;
}

+ (NSArray<UIImage*>*)iconSet:(KeePassIconSet)iconSet {
    return iconSet == kKeePassIconSetClassic ? kKeePassIconSet : kKeePassiOS13SFIconSet;
}

@end
