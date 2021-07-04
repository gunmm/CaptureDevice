//
//  PushFailGuidanceController.m
//  CaptureDeviceProject
//
//  Created by gunmm on 2019/8/24.
//  Copyright © 2019 minzhe. All rights reserved.
//

#import "PushFailGuidanceController.h"

@interface PushFailGuidanceController () <UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic, strong) NSArray *textArray;

@end

@implementation PushFailGuidanceController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.title = @"推流指引";
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.tableFooterView = [UIView new];
    self.tableView.rowHeight = 55;
    NSArray *section1Title = @[@"1. 插耳机并打开mic →→→ 输出100%麦克风声音+20%的扬声器声音", @"2. 插耳机未打开mic →→→ 输出100%的扬声器声音", @"3. 未插耳机打开mic →→→ 输出100%的mic声音（包含着扬声器中输出到mic的声音）", @"4. 未插耳机未打开mic →→→ 输出100%的扬声器声音"];
    NSArray *section2Title = @[@"1. 确认rtmp推流地址正确", @"2. 确认给与了应用软件网络、麦克风、相机、通知权限", @"3. 确认推流页已开始计时"];
    _textArray = @[section1Title, section2Title];
}

#pragma mark -- UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray *titleArray = _textArray[section];
    return titleArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"identifier"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"identifier"];
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.font = [UIFont systemFontOfSize:14];
        cell.textLabel.textColor = mainColor;
    }
    cell.textLabel.text = _textArray[indexPath.section][indexPath.row];
    return cell;
}

#pragma mark -- UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 0.01f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return 50;
    }
    return 50;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"";
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return @"声音相关（打开mic指推流开始页下面的话筒为红色）";
    }
    return @"操作相关";
}

@end
