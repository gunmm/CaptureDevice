//
//  WaterMarkViewController.h
//  CaptureDeviceProject
//
//  Created by gunmm on 2020/1/15.
//  Copyright © 2020 minzhe. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WaterMarkViewController : UITableViewController

@property (nonatomic, copy) void(^changeWaterMarkBlock)(BOOL isOpen);
@property (nonatomic, assign) BOOL isOpen;

@end

NS_ASSUME_NONNULL_END
