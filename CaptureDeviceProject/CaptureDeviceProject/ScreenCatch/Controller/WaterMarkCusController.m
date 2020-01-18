//
//  WaterMarkCusController.m
//  CaptureDeviceProject
//
//  Created by gunmm on 2020/1/16.
//  Copyright © 2020 minzhe. All rights reserved.
//

#import "WaterMarkCusController.h"
#import "WaterMarkView.h"

@interface WaterMarkCusController ()

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIButton *usingBtn;
@property (weak, nonatomic) IBOutlet UIButton *editBtn;

@property (weak, nonatomic) IBOutlet UIView *topView;
@property (nonatomic, strong) NSUserDefaults *userDefaults;
@property (nonatomic, assign) BOOL usingWaterMarkImage;
@property (nonatomic, assign) BOOL hasWaterMarkImage;
@property (nonatomic, assign) BOOL isEditing;

@end

@implementation WaterMarkCusController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"设置水印";
    self.userDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.gunmm.CaptureDeviceProject"];
    NSData *encodedImageStr = [self.userDefaults objectForKey:@"waterMarkImage"];
    UIImage *waterMarkImage = [UIImage imageWithData:encodedImageStr];
    if (waterMarkImage) {
        self.hasWaterMarkImage = YES;
        self.imageView.image = waterMarkImage;
    }
    self.usingWaterMarkImage = [[self.userDefaults objectForKey:@"usingWaterMarkImage"] boolValue];
    
    self.usingBtn.layer.cornerRadius = 6;
    self.usingBtn.layer.masksToBounds = YES;
    self.editBtn.layer.cornerRadius = 6;
    self.editBtn.layer.masksToBounds = YES;

    [self setBtnStatus];
    
}

- (void)setBtnStatus {
    self.imageView.hidden = self.usingBtn.selected = self.editBtn.selected = self.isEditing;
    if (self.usingWaterMarkImage) {
        [self.usingBtn setTitle:@"取消水印" forState:UIControlStateNormal];
    } else {
        [self.usingBtn setTitle:@"使用水印" forState:UIControlStateNormal];
    }
    
    if (!self.hasWaterMarkImage) {
        self.usingBtn.enabled = NO;
        [self.usingBtn setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
        [self.usingBtn setBackgroundColor:[UIColor grayColor]];
    } else {
        self.usingBtn.enabled = YES;
        [self.usingBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [self.usingBtn setBackgroundColor:mainColor];
    }
}

- (IBAction)addBtnAct:(id)sender {
    if (self.isEditing) {
        for (UIView *view in self.topView.subviews) {
            if ([view isMemberOfClass:[WaterMarkView class]]) {
                WaterMarkView *waterMarkView = (WaterMarkView *)view;
                waterMarkView.rotateBtn.hidden = YES;
                waterMarkView.deleteBtn.hidden = YES;
                waterMarkView.textLabel.layer.borderColor = [UIColor clearColor].CGColor;
            }
        }
        CGFloat width = self.topView.height;
        CGFloat height = self.topView.width;

        CGFloat widthScale = width/360.0;
        CGFloat heightScale = height/640.0;
        CGFloat realWidthScale = 1;
        CGFloat realHeightScale = 1;
        
        if (widthScale > 1 || heightScale > 1) {
            if (widthScale < heightScale) {
                realHeightScale = 640.0/height;
                CGFloat nowWidth = width * 640.0 / height;
                height = 640.0;
                realWidthScale = ceilf(nowWidth)/width;
                width = ceilf(nowWidth);
            } else {
                realWidthScale = 360.0/width;
                CGFloat nowHeight = 360.0 * height / width;
                width = 360.0;
                realHeightScale = ceilf(nowHeight)/height;
                height = ceilf(nowHeight);
            }
        }
        
        self.topView.backgroundColor = [UIColor clearColor];
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(height, width), NO, [UIScreen mainScreen].scale);
        [self.topView.layer renderInContext:UIGraphicsGetCurrentContext()];
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        [self.userDefaults setObject:UIImagePNGRepresentation(image) forKey:@"waterMarkImage"];
        
        self.imageView.image = image;
        
        for (UIView *view in self.topView.subviews) {
            if ([view isMemberOfClass:[WaterMarkView class]]) {
                [view removeFromSuperview];
            }
        }
        self.topView.backgroundColor = [UIColor lightGrayColor];

        self.hasWaterMarkImage = YES;
    }
    self.isEditing = !self.isEditing;
    [self setBtnStatus];
}

- (IBAction)usingBtnAct:(id)sender {
    if (self.usingBtn.selected) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"请输入水印内容" message:@""
                                                                preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * action) {
            if (alert.textFields.firstObject.text.length > 0) {
                WaterMarkView *waterMarkView = [[[NSBundle mainBundle] loadNibNamed:@"WaterMarkView" owner:nil options:nil] lastObject];
                waterMarkView.textLabel.text = alert.textFields.firstObject.text;
                [waterMarkView sizeToFit];
                [self.topView addSubview:waterMarkView];
                waterMarkView.center = self.topView.center;
            }
        }];
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction * action) {
        }];
        
        [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.placeholder = @"请输入水印内容";
        }];
        [alert addAction:cancelAction];
        [alert addAction:defaultAction];
        [[NavBgImage getCurrentVC] presentViewController:alert animated:YES completion:nil];
    } else {
        self.usingWaterMarkImage = !self.usingWaterMarkImage;
        [self setBtnStatus];
        [self.userDefaults setObject:@(self.usingWaterMarkImage) forKey:@"usingWaterMarkImage"];
        if (self.saveWaterBlock) {
            self.saveWaterBlock(self.usingWaterMarkImage);
        }
    }
}

@end
