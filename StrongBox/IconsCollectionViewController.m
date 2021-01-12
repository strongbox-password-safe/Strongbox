//
//  IconsCollectionViewController.m
//  Strongbox
//
//  Created by Mark on 22/02/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "IconsCollectionViewController.h"
#import "NodeIconHelper.h"
#import "IconViewCell.h"
#import "Utils.h"
#import "IconsSectionHeaderReusableView.h"

@interface IconsCollectionViewController () <UICollectionViewDataSource, UICollectionViewDelegate>

@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet UIView *customIconsView;

@property NSArray<NodeIcon*>* customIcons;

@end

@implementation IconsCollectionViewController

- (IBAction)onCancel:(id)sender {
    self.onDone(NO, nil);
}

- (IBAction)onUseDefault:(id)sender {
    self.onDone(YES, nil);
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.customIcons = self.customIconSet ? self.customIconSet.allObjects : @[];
        
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;

    [self.collectionView registerNib:[UINib nibWithNibName:@"IconCellView" bundle:nil] forCellWithReuseIdentifier:@"CELL"];
    [self.collectionView registerNib:[UINib nibWithNibName:@"IconsSectionHeaderReusableView" bundle:nil]
          forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                 withReuseIdentifier:@"IconsSectionHeaderReusableView"];
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section
{
    if (![self hasCustomIcons]) {
        return CGSizeZero;
    }else {
        return CGSizeMake(collectionView.frame.size.width,50);
    }
}

- (BOOL)hasCustomIcons {
    return self.customIcons.firstObject != nil;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return [self hasCustomIcons] ? 2 : 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return ([self hasCustomIcons] && section == 0) ? self.customIcons.count : [NodeIconHelper getIconSet:self.predefinedKeePassIconSet].count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    if([self hasCustomIcons] && indexPath.section == 0) {
        IconViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"CELL" forIndexPath:indexPath];
        NodeIcon* icon = self.customIcons[indexPath.row];
        UIImage* image = [NodeIconHelper getNodeIcon:icon];
        
        if(image) {
            cell.imageView.image = image;
        }
        
        return cell;
    }
    else {
        IconViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"CELL" forIndexPath:indexPath];
        cell.imageView.image = [NodeIconHelper getNodeIcon:[NodeIcon withPreset:indexPath.item] predefinedIconSet:self.predefinedKeePassIconSet];
        return cell;
    }
}

-(UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind
                                atIndexPath:(NSIndexPath *)indexPath {
    UICollectionReusableView *reusableView = nil;
    
    if (kind == UICollectionElementKindSectionHeader) {
        IconsSectionHeaderReusableView *collectionHeader = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"IconsSectionHeaderReusableView" forIndexPath:indexPath];
        
        collectionHeader.labelTitle.text = ([self hasCustomIcons] && indexPath.section == 0) ?
        NSLocalizedString(@"icons_vc_header_database_icons_title", @"Database Icons") :
        NSLocalizedString(@"icons_vc_header_keepass_icons_title", @"KeePass Icons");
        
        reusableView = collectionHeader;
    }
    else {
        reusableView = [[UICollectionReusableView alloc] init];
    }
    
    return reusableView;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if([self hasCustomIcons] && indexPath.section == 0) {
        NodeIcon* icon = self.customIcons[indexPath.row];
        self.onDone(YES, icon);
    }
    else {
        self.onDone(YES, [NodeIcon withPreset:indexPath.item]);
    }
}

@end
