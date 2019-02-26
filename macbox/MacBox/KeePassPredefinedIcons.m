//
//  KeePassPredefinedIcons.m
//  Strongbox
//
//  Created by Mark on 25/02/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "KeePassPredefinedIcons.h"
#import "NSArray+Extensions.h"
#import <Cocoa/Cocoa.h>

@interface KeePassPredefinedIcons ()


@end

static NSArray<NSImage*> *kKeePassIconSet;

@implementation KeePassPredefinedIcons

+ (void)initialize {
    if(self == [KeePassPredefinedIcons class]) {
        kKeePassIconSet = getKeePassIconSet();
        
    }
}

+(NSArray<NSImage *> *)icons {
    return kKeePassIconSet;
}

static NSArray<NSImage*>* getKeePassIconSet() {
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
        return [NSImage imageNamed:obj];
    }];
}

@end
