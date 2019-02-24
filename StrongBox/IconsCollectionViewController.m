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

@interface IconsCollectionViewController () <UICollectionViewDataSource, UICollectionViewDelegate>

@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;

@end

@implementation IconsCollectionViewController

- (IBAction)onCancel:(id)sender {
    self.onDone(NO, -1);
}

- (IBAction)onUseDefault:(id)sender {
    self.onDone(YES, -1);
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;

    [self.collectionView registerNib:[UINib nibWithNibName:@"IconCellView" bundle:nil] forCellWithReuseIdentifier:@"CELL"];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [NodeIconHelper iconSet].count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    IconViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"CELL" forIndexPath:indexPath];
    cell.imageView.image = [NodeIconHelper iconSet][indexPath.item];
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    self.onDone(YES, indexPath.item);
}

@end
