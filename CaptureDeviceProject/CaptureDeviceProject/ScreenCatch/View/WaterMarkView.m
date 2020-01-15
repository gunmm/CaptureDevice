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
    
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    titleLabel.text = @"s我是";
    titleLabel.backgroundColor = [UIColor clearColor];
    [self addSubview:titleLabel];
}

@end
