//
//  NodeIconHelper.m
//  Strongbox
//
//  Created by Mark on 12/11/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "NodeIconHelper.h"
#import "NSArray+Extensions.h"
#import "Utils.h"
#import "ConcurrentMutableDictionary.h"

#if TARGET_OS_IPHONE
#else
#import "Settings.h"
#endif

static IMAGE_TYPE_PTR kPwSafeFolderImage;
static IMAGE_TYPE_PTR kPwSafeRecordImage;

static IMAGE_TYPE_PTR kFolderImage;
static IMAGE_TYPE_PTR kSmallYellowFolderImage;
static IMAGE_TYPE_PTR kSmallLockImage;

static NSArray<IMAGE_TYPE_PTR> *kKeePassIconSet;
static NSArray<IMAGE_TYPE_PTR> *kKeePassiOS13SFIconSet;
static NSArray<IMAGE_TYPE_PTR> *kKeePassXCIconSet;

@implementation NodeIconHelper

+ (void)initialize {
    if(self == [NodeIconHelper class]) {
#if TARGET_OS_IPHONE
        kPwSafeFolderImage = [UIImage imageNamed:@"folder"];
        kPwSafeRecordImage = [UIImage imageNamed:@"document"];
#else
        kFolderImage = [NSImage imageNamed:@"blue-folder-cropped-256"];
        kSmallYellowFolderImage = [NSImage imageNamed:@"Places-folder-yellow-icon-32"];
        kSmallLockImage = [NSImage imageNamed:@"lock-48"];
#endif
    }
}

static NSArray<IMAGE_TYPE_PTR>* loadKeePassiOS13SFIconSet(void) {
    NSArray<NSString*>* names = @[@"lock.fill",
                                  @"globe",
                                  @"exclamationmark.triangle",
                                  @"hifispeaker",
                                  @"pin.circle",
                                  @"message.circle",
                                  @"cube.box",
                                  @"square.and.pencil",
                                  @"exclamationmark.bubble",
                                  @"creditcard",
                                  @"person.crop.square",
                                  @"camera",
                                  @"antenna.radiowaves.left.and.right",
                                  @"square.stack.3d.up",
                                  @"power",
                                  @"doc.text.viewfinder",
                                  @"star.circle",
                                  @"smallcircle.circle",
                                  @"tv",
                                  @"envelope.open",
                                  @"gear",
                                  @"doc.on.clipboard",
                                  @"doc.plaintext",
                                  @"doc.richtext",
                                  @"bolt.circle",
                                  @"envelope.badge",
                                  @"desktopcomputer",
                                  @"phone.circle",
                                  @"at",
                                  @"terminal.fill", 
                                  @"terminal",      
                                  @"printer",
                                  @"perspective",
                                  @"square",
                                  @"wrench",
                                  @"slider.horizontal.below.rectangle",
                                  @"selection.pin.in.out",
                                  @"percent",
                                  @"uiwindow.split.2x1",
                                  @"clock",
                                  @"magnifyingglass.circle",
                                  @"hexagon",
                                  @"memories",
                                  @"trash.circle.fill",
                                  @"mappin.circle",
                                  @"clear",
                                  @"questionmark.circle",
                                  @"archivebox",
                                  @"folder.fill",
                                  @"folder.badge.person.crop",
                                  @"folder.circle",
                                  @"lock.open",
                                  @"lock",
                                  @"checkmark.circle",
                                  @"pencil",
                                  @"book.circle",
                                  @"airplane",
                                  @"text.justify",
                                  @"person.badge.plus",
                                  @"hammer",
                                  @"house",
                                  @"star",
                                  @"tortoise",
                                  @"flame",
                                  @"burn",
                                  @"w.square",
                                  @"dollarsign.circle",
                                  @"signature",
                                  @"equal.square"];
    
    NSMutableArray *mut = names.mutableCopy;
    
    if (@available(iOS 15.4, macOS 12.3, *)) {
        mut[58] = @"person.badge.key.fill";
    }
    
    return [mut map:^id _Nonnull(NSString * _Nonnull obj, NSUInteger idx) {
#if TARGET_OS_IPHONE
        IMAGE_TYPE_PTR img;
        if (@available(iOS 16.0, *)) {
            img = [[UIImage systemImageNamed:obj] imageWithConfiguration:[UIImageSymbolConfiguration configurationPreferringMonochrome]];
        } else {
            img = [UIImage systemImageNamed:obj];
        }
        
        return img ? [img imageWithTintColor:UIColor.blueColor renderingMode:UIImageRenderingModeAlwaysTemplate] : [[UIImage systemImageNamed:@"lock.fill"] imageWithTintColor:UIColor.blueColor renderingMode:UIImageRenderingModeAlwaysTemplate];
#else
        IMAGE_TYPE_PTR img = [NSImage imageWithSystemSymbolName:obj accessibilityDescription:nil];
        
        return img ? img : kSmallLockImage;
#endif
    }];
}


static NSArray<IMAGE_TYPE_PTR>* loadKeePassXCIconSet(void) {
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
#if TARGET_OS_IPHONE
        return [UIImage imageNamed:obj];
#else
        return [NSImage imageNamed:obj];
#endif
    }];
}

static NSArray<IMAGE_TYPE_PTR>* loadKeePassIconSet(void) {
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
#if TARGET_OS_IPHONE
        return [UIImage imageNamed:obj];
#else
        return [NSImage imageNamed:obj];
#endif
    }];
}

+ (IMAGE_TYPE_PTR)defaultIcon {
    return [NodeIconHelper getNodeIcon:NodeIcon.defaultNodeIcon];
}

+ (IMAGE_TYPE_PTR)getIconForNode:(Node*)vm predefinedIconSet:(KeePassIconSet)predefinedIconSet format:(DatabaseFormat)format {
    return [self getIconForNode:vm predefinedIconSet:predefinedIconSet format:format large:NO];
}

+ (IMAGE_TYPE_PTR)getIconForNode:(Node*)vm predefinedIconSet:(KeePassIconSet)predefinedIconSet format:(DatabaseFormat)format large:(BOOL)large {
    return [self getNodeIcon:vm.icon predefinedIconSet:predefinedIconSet format:format isGroup:vm.isGroup large:large];
}

+ (IMAGE_TYPE_PTR)getNodeIcon:(NodeIcon *)icon {
    return [self getNodeIcon:icon predefinedIconSet:kKeePassIconSetSfSymbols format:kKeePass4 isGroup:NO];
}

+ (IMAGE_TYPE_PTR)getNodeIcon:(NodeIcon *)icon predefinedIconSet:(KeePassIconSet)predefinedIconSet {
    return [self getNodeIcon:icon predefinedIconSet:predefinedIconSet format:kKeePass4 isGroup:NO];
}

+ (IMAGE_TYPE_PTR)getNodeIcon:(NodeIcon *)icon predefinedIconSet:(KeePassIconSet)predefinedIconSet format:(DatabaseFormat)format {
    return [self getNodeIcon:icon predefinedIconSet:predefinedIconSet format:format isGroup:NO];
}

+ (IMAGE_TYPE_PTR)getNodeIcon:(NodeIcon *)icon predefinedIconSet:(KeePassIconSet)predefinedIconSet format:(DatabaseFormat)format isGroup:(BOOL)isGroup {
    return [self getNodeIcon:icon predefinedIconSet:predefinedIconSet format:format isGroup:isGroup large:NO];
}

+ (IMAGE_TYPE_PTR)getNodeIcon:(NodeIcon *)icon predefinedIconSet:(KeePassIconSet)predefinedIconSet format:(DatabaseFormat)format isGroup:(BOOL)isGroup large:(BOOL)large {
    if(format == kPasswordSafe) {
#if TARGET_OS_IPHONE
        return isGroup ? kPwSafeFolderImage : kPwSafeRecordImage;
#else
        if ( !large ) {
            NSArray<IMAGE_TYPE_PTR>* iconSet = [NodeIconHelper getIconSet:kKeePassIconSetSfSymbols];
            return isGroup ? iconSet[48] : iconSet[0];
        }
        else {
            return isGroup ? kFolderImage : kSmallLockImage;
        }
#endif
    }
    else {
        NSArray<IMAGE_TYPE_PTR>* iconSet = [NodeIconHelper getIconSet:predefinedIconSet];
        
        if (icon == nil) {
            return isGroup ? iconSet[48] : iconSet[0];
        }

        if(icon.isCustom) {
            if( icon.customIconWidth != icon.customIconHeight && MIN(icon.customIconWidth, icon.customIconHeight) > 512 ) {
                slog(@"🔴 Down Sampling icon...");
                return scaleImage(icon.customIcon, CGSizeMake(192, 192));
            }
            else {
                return icon.customIcon;
            }
        }
        else if(icon.preset >= 0 && icon.preset < iconSet.count) {
            return iconSet[icon.preset];
        }
        else {
            return isGroup ? iconSet[48] : iconSet[0];
        }
    }
}

+ (NSArray<IMAGE_TYPE_PTR>*)getKeePassIconSet {
    if (kKeePassIconSet == nil) {
        kKeePassIconSet = loadKeePassIconSet();
    }
    
    return kKeePassIconSet;
}

+ (NSArray<IMAGE_TYPE_PTR>*)getKeePassiOS13SFIconSet {
    if (kKeePassiOS13SFIconSet == nil) {
        kKeePassiOS13SFIconSet = loadKeePassiOS13SFIconSet();
    }
    
    return kKeePassiOS13SFIconSet;
}

+ (NSArray<IMAGE_TYPE_PTR>*)getKeePassXCIconSet {
    if (kKeePassXCIconSet == nil) {
        kKeePassXCIconSet = loadKeePassXCIconSet();
    }
    
    return kKeePassXCIconSet;
}

+ (NSArray<IMAGE_TYPE_PTR>*)getIconSet:(KeePassIconSet)iconSet {
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
