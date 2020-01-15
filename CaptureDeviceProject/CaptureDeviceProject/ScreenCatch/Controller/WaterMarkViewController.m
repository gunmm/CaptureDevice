//
//  WaterMarkViewController.m
//  CaptureDeviceProject
//
//  Created by gunmm on 2020/1/15.
//  Copyright © 2020 minzhe. All rights reserved.
//

#import "WaterMarkViewController.h"

@interface WaterMarkViewController ()

@property (weak, nonatomic) IBOutlet UITextField *waterTextFiled;
@property (weak, nonatomic) IBOutlet UISegmentedControl *colorSegment;
@property (weak, nonatomic) IBOutlet UISegmentedControl *fontSizeSegment;
@property (weak, nonatomic) IBOutlet UISegmentedControl *locationSegment;
@property (weak, nonatomic) IBOutlet UISwitch *waterSwitch;

@end

@implementation WaterMarkViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    [self initView];
}

- (void)initView {
    self.title = @"设置水印";
    UIBarButtonItem *saveBtn = [[UIBarButtonItem alloc] initWithTitle:@"保存" style:UIBarButtonItemStylePlain target:self action:@selector(saveBtnClicked)];
    [saveBtn setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[UIFont systemFontOfSize:14],NSFontAttributeName, nil] forState:UIControlStateNormal];
    [self.navigationItem setRightBarButtonItem:saveBtn];
    self.tableView.tableFooterView = [UIView new];
    self.waterSwitch.on = self.isOpen;
    
    NSDictionary *waterMarkParam = [[NSUserDefaults standardUserDefaults] objectForKey:@"waterMarkParam"];
    self.waterTextFiled.text = [waterMarkParam objectForKey:@"waterText"];
    self.colorSegment.selectedSegmentIndex = [[waterMarkParam objectForKey:@"color"] integerValue];
    self.fontSizeSegment.selectedSegmentIndex = [[waterMarkParam objectForKey:@"font"] integerValue];
    self.locationSegment.selectedSegmentIndex = [[waterMarkParam objectForKey:@"location"] integerValue];
}

- (void)saveBtnClicked {
    if (self.waterTextFiled.text.length == 0) {
        [self.view showHint:@"请输入水印内容"];
        self.waterSwitch.on = NO;
        return;
    }
    
    NSDictionary *waterMarkParam = @{
        @"waterText" : self.waterTextFiled.text,
        @"color" : @(self.colorSegment.selectedSegmentIndex),
        @"font" : @(self.fontSizeSegment.selectedSegmentIndex),
        @"location" : @(self.locationSegment.selectedSegmentIndex)
    };
    [[NSUserDefaults standardUserDefaults] setObject:waterMarkParam forKey:@"waterMarkParam"];
    
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)switchBtnAct:(id)sender {
    if (!self.waterSwitch.on) {
        if (self.changeWaterMarkBlock) {
            self.changeWaterMarkBlock(NO);
        }
    } else {
        if (self.waterTextFiled.text.length == 0) {
            [self.view showHint:@"请输入水印内容"];
            self.waterSwitch.on = NO;
            return;
        }
        NSDictionary *waterMarkParam = @{
            @"waterText" : self.waterTextFiled.text,
            @"color" : @(self.colorSegment.selectedSegmentIndex),
            @"font" : @(self.fontSizeSegment.selectedSegmentIndex),
            @"location" : @(self.locationSegment.selectedSegmentIndex)
        };
        [[NSUserDefaults standardUserDefaults] setObject:waterMarkParam forKey:@"waterMarkParam"];
        
        if (self.changeWaterMarkBlock) {
            self.changeWaterMarkBlock(YES);
        }
    }
    
}

@end
