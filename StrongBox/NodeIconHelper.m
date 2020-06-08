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
static UIColor *kSandyFolderColor;  // Maybe just use standard system blue coolor ? TODO:

static NSArray<UIImage*> *kKeePassIconSet;
static NSArray<UIImage*> *kKeePassiOS13SFIconSet;
static NSArray<UIImage*> *kKeePassXCIconSet;

@implementation NodeIconHelper

+ (void)initialize {
    if(self == [NodeIconHelper class]) {
        kPwSafeFolderImage = [UIImage imageNamed:@"folder"];
        kPwSafeRecordImage = [UIImage imageNamed:@"document"];
        kSandyFolderColor = ColorFromRGB(0xFAB805);
    }
}

static NSArray<UIImage*>* loadKeePassiOS13SFIconSet() {
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
        return loadKeePassIconSet();
    }
}

static NSArray<UIImage*>* loadKeePassXCIconSet() {
    NSArray<NSString*>* names = @[@"KPXC_C00_Password",
                                  @"KPXC_C01_Package_Network",
                                  @"KPXC_C02_MessageBox_Warning",
                                  @"KPXC_C03_Server",
                                  @"KPXC_C04_Klipper",
                                  @"KPXC_C05_Edu_Languages",
                                  @"KPXC_C06_KCMDF",
                                  @"KPXC_C07_Kate",
                                  @"KPXC_C08_Socket",
                                  @"KPXC_C09_Identity",
                                  @"KPXC_C10_Kontact",
                                  @"KPXC_C11_Camera",
                                  @"KPXC_C12_IRKickFlash",
                                  @"KPXC_C13_KGPG_Key3",
                                  @"KPXC_C14_Laptop_Power",
                                  @"KPXC_C15_Scanner",
                                  @"KPXC_C16_Mozilla_Firebird",
                                  @"KPXC_C17_CDROM_Unmount",
                                  @"KPXC_C18_Display",
                                  @"KPXC_C19_Mail_Generic",
                                  @"KPXC_C20_Misc",
                                  @"KPXC_C21_KOrganizer",
                                  @"KPXC_C22_ASCII",
                                  @"KPXC_C23_Icons",
                                  @"KPXC_C24_Connect_Established",
                                  @"KPXC_C25_Folder_Mail",
                                  @"KPXC_C26_FileSave",
                                  @"KPXC_C27_NFS_Unmount",
                                  @"KPXC_C28_Message",
                                  @"KPXC_C29_KGPG_Term",
                                  @"KPXC_C30_Konsole",
                                  @"KPXC_C31_FilePrint",
                                  @"KPXC_C32_FSView",
                                  @"KPXC_C33_Run",
                                  @"KPXC_C34_Configure",
                                  @"KPXC_C35_KRFB",
                                  @"KPXC_C36_Ark",
                                  @"KPXC_C37_KPercentage",
                                  @"KPXC_C38_Samba_Unmount",
                                  @"KPXC_C39_History",
                                  @"KPXC_C40_Mail_Find",
                                  @"KPXC_C41_VectorGfx",
                                  @"KPXC_C42_KCMMemory",
                                  @"KPXC_C43_Trashcan_Full",
                                  @"KPXC_C44_KNotes",
                                  @"KPXC_C45_Cancel",
                                  @"KPXC_C46_Help",
                                  @"KPXC_C47_KPackage",
                                  @"KPXC_C48_Folder",
                                  @"KPXC_C49_Folder_Blue_Open",
                                  @"KPXC_C50_Folder_Tar",
                                  @"KPXC_C51_Decrypted",
                                  @"KPXC_C52_Encrypted",
                                  @"KPXC_C53_Apply",
                                  @"KPXC_C54_Signature",
                                  @"KPXC_C55_Thumbnail",
                                  @"KPXC_C56_KAddressBook",
                                  @"KPXC_C57_View_Text",
                                  @"KPXC_C58_KGPG",
                                  @"KPXC_C59_Package_Development",
                                  @"KPXC_C60_KFM_Home",
                                  @"KPXC_C61_Services",
                                  @"KPXC_C62_Tux",
                                  @"KPXC_C63_Feather",
                                  @"KPXC_C64_Apple",
                                  @"KPXC_C65_W",
                                  @"KPXC_C66_Money",
                                  @"KPXC_C67_Certificate",
                                  @"KPXC_C68_Smartphone"];
    
    return [names map:^id _Nonnull(NSString * _Nonnull obj, NSUInteger idx) {
        return [UIImage imageNamed:obj];
    }];
}

static NSArray<UIImage*>* loadKeePassIconSet() {
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
    return kSandyFolderColor; // Maybe just use standard system blue coolor ? TODO:
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
    if(model.database.format == kPasswordSafe) {
        return isGroup ? kPwSafeFolderImage : kPwSafeRecordImage;
    }
    
    NSArray<UIImage*>* iconSet = [NodeIconHelper getIconSet:model.metadata.keePassIconSet];
        
    if(customIconUuid) {
        return [NodeIconHelper getCustomIcon:customIconUuid customIcons:model.database.customIcons];
    }
    else if(iconId && iconId.intValue >= 0 && iconId.intValue < iconSet.count) {
        return iconSet[iconId.intValue];
    }
    else {
        return isGroup ? iconSet[48] : iconSet[0];
    }
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

+ (NSArray<UIImage*>*)getKeePassIconSet {
    if (kKeePassIconSet == nil) {
        kKeePassIconSet = loadKeePassIconSet();
    }
    
    return kKeePassIconSet;
}

+ (NSArray<UIImage*>*)getKeePassiOS13SFIconSet {
    if (kKeePassiOS13SFIconSet == nil) {
        kKeePassiOS13SFIconSet = loadKeePassiOS13SFIconSet();
    }
    
    return kKeePassiOS13SFIconSet;
}

+ (NSArray<UIImage*>*)getKeePassXCIconSet {
    if (kKeePassXCIconSet == nil) {
        kKeePassXCIconSet = loadKeePassXCIconSet();
    }
    
    return kKeePassXCIconSet;
}

+ (NSArray<UIImage*>*)getIconSet:(KeePassIconSet)iconSet {
    if (iconSet == kKeePassIconSetKeePassXC) {
        return [NodeIconHelper getKeePassXCIconSet];
    }
    else if (iconSet == kKeePassIconSetClassic) {
        return [NodeIconHelper getKeePassIconSet];
    }
    else {
        return [NodeIconHelper getKeePassiOS13SFIconSet];
    }
}

@end
