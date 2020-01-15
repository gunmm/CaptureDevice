//
//  ScreenCatchViewController.m
//  CaptureDeviceProject
//
//  Created by gunmm on 2019/8/3.
//  Copyright © 2019 minzhe. All rights reserved.
//

#import "ScreenCatchViewController.h"
#import "ClickJumpTableViewCell.h"
#import "SetPushUrlViewController.h"
#import "SelectListViewController.h"
#import "SelectListModel.h"
#import "ScreenCatchTableFooterView.h"
#import <UserNotifications/UserNotifications.h>
#import "PushFailGuidanceController.h"
#import "NetWorking.h"
#import "BaseDeviceManager.h"
#import "PayManager.h"
#import "WaterMarkView.h"

@interface ScreenCatchViewController () <UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (nonatomic, strong) NSArray *sectionHeadTitleArray;

@property (nonatomic, strong) NSMutableArray <SelectListModel *> *screenOrientationdataList;
@property (nonatomic, strong) NSMutableArray <SelectListModel *> *applicationVoicedataList;
@property (nonatomic, strong) NSMutableArray <SelectListModel *> *micVoicedataList;

@property (nonatomic, copy) NSString *urlStr;
@property (nonatomic, copy) NSString *screenOrientation;
@property (nonatomic, copy) NSString *applicationVoice;
@property (nonatomic, copy) NSString *micVoice;

@property (nonatomic, strong) SelectListModel *screenOrientationModel;
@property (nonatomic, strong) SelectListModel *applicationVoiceModel;
@property (nonatomic, strong) SelectListModel *micVoiceModel;

@property (nonatomic, strong) NSUserDefaults *userDefaults;

@property (nonatomic, strong) ScreenCatchTableFooterView *footerView;

@end

@implementation ScreenCatchViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.title = @"录屏推流";
    
    [self initData];
    [self initView];

    UIView *waterMarkView = [[WaterMarkView alloc] initWithFrame:CGRectMake(0, 0, 375, 667)];
    CGSize s = waterMarkView.bounds.size;
    UIGraphicsBeginImageContextWithOptions(s, NO, [UIScreen mainScreen].scale);
    [waterMarkView.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    
    
    NSData *data = UIImageJPEGRepresentation(image, 1.0f);
    NSString *encodedImageStr = [data base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
//    NSURL *groupURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.gunmm.CaptureDeviceProject"];
//    NSURL *fileURL = [groupURL URLByAppendingPathComponent:@"waterMarkView.png"];
//    [UIImagePNGRepresentation(image) writeToURL:fileURL atomically:YES];
    
    [self.userDefaults setObject:encodedImageStr forKey:@"waterMarkImage"];

}


- (void)initData {
    self.sectionHeadTitleArray = @[
        @"推流地址",
        @"屏幕方向",
        @"音量设置",
        @"",
    ];
    
    self.userDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.gunmm.CaptureDeviceProject"];
    NSInteger screenOrientationValue = [[self.userDefaults objectForKey:@"screenOrientationValue"] integerValue];
    NSInteger applicationVoiceValue = [[self.userDefaults objectForKey:@"applicationVoiceValue"] integerValue] == 0 ? 10 : [[self.userDefaults objectForKey:@"applicationVoiceValue"] integerValue];
    NSInteger micVoiceValue = [[self.userDefaults objectForKey:@"micVoiceValue"] integerValue] == 0 ? 80 : [[self.userDefaults objectForKey:@"micVoiceValue"] integerValue];
    
    self.screenOrientationdataList = [NSMutableArray array];
    self.applicationVoicedataList = [NSMutableArray array];
    self.micVoicedataList = [NSMutableArray array];
    
    NSArray *titleArray = @[@"竖屏", @"横屏（Home键在右）", @"横屏（Home键在左）"];
    for (NSInteger i = 0; i < titleArray.count; i++) {
        SelectListModel *model = [[SelectListModel alloc] initWithValueNumber:i titleString:titleArray[i]];
        [self.screenOrientationdataList addObject:model];
        if (screenOrientationValue == i) {
            self.screenOrientationModel = model;
        }
    }
    
    for (int i = 5; i <= 100;) {
        NSString *titleString = @"";
        if (i == 10) {
            titleString = [NSString stringWithFormat:@"音量 %d%%（推荐）", i];
        } else {
            titleString = [NSString stringWithFormat:@"音量 %d%%", i];
        }
        SelectListModel *model = [[SelectListModel alloc] initWithValueNumber:i titleString:titleString];
        [self.applicationVoicedataList addObject:model];
        if (applicationVoiceValue == i) {
            self.applicationVoiceModel = model;
        }
        i += 5;
    }
    
    for (int i = 5; i <= 100;) {
        NSString *titleString = @"";
        if (i == 80) {
            titleString = [NSString stringWithFormat:@"音量 %d%%（推荐）", i];
        } else {
            titleString = [NSString stringWithFormat:@"音量 %d%%", i];
        }
        SelectListModel *model = [[SelectListModel alloc] initWithValueNumber:i titleString:titleString];
        [self.micVoicedataList addObject:model];
        if (micVoiceValue == i) {
            self.micVoiceModel = model;
        }
        i += 5;
    }
}

- (void)initView {
    [self.tableView registerNib:[UINib nibWithNibName:NSStringFromClass([ClickJumpTableViewCell class]) bundle:nil] forCellReuseIdentifier:NSStringFromClass([ClickJumpTableViewCell class])];
}

#pragma mark -- UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 2) {
        return 2;
    }
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ClickJumpTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass([ClickJumpTableViewCell class])];
    NSString *titleString = @"";
    if (indexPath.section == 0) {
        titleString = self.urlStr.length > 0 ? self.urlStr : @"设置地址";
    } else if (indexPath.section == 1) {
        titleString = self.screenOrientationModel.titleString;
    } else if (indexPath.section == 2) {
        if (indexPath.row == 0) {
            titleString = [NSString stringWithFormat:@"应用%@",self.applicationVoiceModel.titleString];;
        } else if (indexPath.row == 1) {
            titleString = [NSString stringWithFormat:@"麦克风%@",self.micVoiceModel.titleString];;
        }
    }
    cell.titleString = titleString;
    return cell;
}

#pragma mark -- UITableViewDelegate

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sectionHeadTitleArray[section];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"";
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (section == 1) {
        return 300;
    }
    return 0.001f;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if (section == 1) {
        if (self.urlStr.length > 0) {
            UserInfoKeyChain *userInfoKeyChain = [UserInfoKeyChain keychainInstance];
            long expirationTimeLong = [userInfoKeyChain.expirationTime longValue];
            NSDate *dateNow = [NSDate date];//现在时间
            long dateNowTimeLong = [dateNow timeIntervalSince1970];
            if (dateNowTimeLong > expirationTimeLong) {
                [[PayManager manager] getRequestAppleProduct];
            } else {
                self.footerView.showBtn = YES;
            }
        } else {
            self.footerView.showBtn = NO;
        }
        return self.footerView;
    }
    return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    __weak typeof(self) weakSelf = self;
    if (indexPath.section == 0) {
        SetPushUrlViewController *setPushUrlViewController = [[SetPushUrlViewController alloc] init];
        setPushUrlViewController.urlStr = self.urlStr;
        setPushUrlViewController.savePushUrlBlock = ^(NSString * _Nonnull pushUrl) {
            weakSelf.urlStr = pushUrl;
            [weakSelf.tableView reloadData];
            [weakSelf.userDefaults setObject:pushUrl forKey:@"urlStr"];
        };
        [self.navigationController pushViewController:setPushUrlViewController animated:YES];
    } else {
        SelectListViewController *selectListViewController = [[SelectListViewController alloc] init];
        if (indexPath.section == 1) {
            selectListViewController.dataList = self.screenOrientationdataList;
            selectListViewController.currentSelectCellModel = self.screenOrientationModel;
            selectListViewController.selectListCellBlock = ^(SelectListModel * _Nonnull selectCellModel) {
                weakSelf.screenOrientationModel = selectCellModel;
                [weakSelf.tableView reloadData];
                [weakSelf.userDefaults setObject:@(selectCellModel.valueNumber) forKey:@"screenOrientationValue"];
            };
        } else if (indexPath.section == 2) {
            if (indexPath.row == 0) {
                selectListViewController.dataList = self.applicationVoicedataList;
                selectListViewController.currentSelectCellModel = self.applicationVoiceModel;
                selectListViewController.selectListCellBlock = ^(SelectListModel * _Nonnull selectCellModel) {
                    weakSelf.applicationVoiceModel = selectCellModel;
                    [weakSelf.tableView reloadData];
                    [weakSelf.userDefaults setObject:@(selectCellModel.valueNumber) forKey:@"applicationVoiceValue"];
                };
            } else if (indexPath.row == 1) {
                selectListViewController.dataList = self.micVoicedataList;
                selectListViewController.currentSelectCellModel = self.micVoiceModel;
                selectListViewController.selectListCellBlock = ^(SelectListModel * _Nonnull selectCellModel) {
                    weakSelf.micVoiceModel = selectCellModel;
                    [weakSelf.tableView reloadData];
                    [weakSelf.userDefaults setObject:@(selectCellModel.valueNumber) forKey:@"micVoiceValue"];
                };
            }
        }
        if (selectListViewController.dataList.count > 0) {
            [self.navigationController pushViewController:selectListViewController animated:YES];
        }
    }
}

#pragma mark -- get

- (ScreenCatchTableFooterView *)footerView {
    if (!_footerView) {
        _footerView = [ScreenCatchTableFooterView loadScreenCatchTableFooterView];
        __weak typeof(self) weakSelf = self;
        _footerView.failedBtnActBlock = ^{
            [weakSelf.navigationController pushViewController:[PushFailGuidanceController new] animated:YES];
        };
    }
    return _footerView;
}

@end
