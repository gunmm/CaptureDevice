//
//  WaterMarkView.h
//  ScreenCapture
//
//  Created by gunmm on 2020/1/14.
//  Copyright © 2020 minzhe. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WaterMarkView : UIView

@property (weak, nonatomic) IBOutlet UILabel *textLabel;
@property (weak, nonatomic) IBOutlet UIButton *deleteBtn;
@property (weak, nonatomic) IBOutlet UIButton *rotateBtn;

@end

NS_ASSUME_NONNULL_END
