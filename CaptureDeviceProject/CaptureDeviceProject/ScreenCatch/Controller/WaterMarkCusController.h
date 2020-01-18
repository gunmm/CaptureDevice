//
//  WaterMarkCusController.h
//  CaptureDeviceProject
//
//  Created by gunmm on 2020/1/16.
//  Copyright © 2020 minzhe. All rights reserved.
//

#import "BaseViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface WaterMarkCusController : BaseViewController

@property (nonatomic, copy) void(^saveWaterBlock)(BOOL usingWater);

@end

NS_ASSUME_NONNULL_END
