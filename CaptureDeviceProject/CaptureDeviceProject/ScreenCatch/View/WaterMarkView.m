//
//  WaterMarkView.m
//  ScreenCapture
//
//  Created by gunmm on 2020/1/14.
//  Copyright © 2020 minzhe. All rights reserved.
//

#import "WaterMarkView.h"

@implementation WaterMarkView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setUpUI];
    }
    return self;
}

- (void)setUpUI {
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"s我是测试测试";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.center = self.center;
    [self addSubview:titleLabel];
}

@end
