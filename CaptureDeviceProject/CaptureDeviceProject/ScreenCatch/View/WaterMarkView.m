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
        self.backgroundColor = [UIColor redColor];
    }
    return self;
}

- (void)setUpUI {
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 500, 200, 100)];
    titleLabel.backgroundColor = [UIColor greenColor];
    titleLabel.text = @"s我是测试测试";
    [self addSubview:titleLabel];
}

@end
