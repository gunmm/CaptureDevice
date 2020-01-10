//
//  UserInfoKeyChain.m
//  CaptureDeviceProject
//
//  Created by minzhe on 2019/12/27.
//  Copyright © 2019 minzhe. All rights reserved.
//

#import "UserInfoKeyChain.h"

@implementation UserInfoKeyChain

+ (instancetype)keychainInstance {
    NSError *error = nil;
    YYKeychainItem *item = [[YYKeychainItem alloc] init];
    item.service = [self keychainService];
    item.account = [self keychainAccount];
    item = [YYKeychain selectOneItem:item error:&error];
    if (error || !item) {
        UserInfoKeyChain *userInfoKeyChain = [[UserInfoKeyChain alloc] init];
        userInfoKeyChain.isCreate = @"";

        NSString *deviceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"deviceId"];
        if (deviceId.length == 0) {
            deviceId = [[NSUUID UUID] UUIDString];
            userInfoKeyChain.isCreate = @"1";
        }
        NSDate *dateNow = [NSDate date];//现在时间
        long downLoadTimeLong = [dateNow timeIntervalSince1970];
        long expirationTimeLong = [dateNow timeIntervalSince1970] + 7 * 24 * 3600;
        userInfoKeyChain.deviceId = deviceId;
        userInfoKeyChain.downLoadTime = [NSString stringWithFormat:@"%ld", downLoadTimeLong];
        userInfoKeyChain.expirationTime = [NSString stringWithFormat:@"%ld", expirationTimeLong];
        [userInfoKeyChain saveToKeychain];
        return userInfoKeyChain;
    }
    else {
        UserInfoKeyChain *userInfoKeyChain = [self modelWithJSON:item.password];
        userInfoKeyChain.isCreate = @"";
        return userInfoKeyChain;
    }
}

+ (NSError *)clearKeychain {
    NSError *error = nil;
    [YYKeychain deletePasswordForService:[self keychainService]
                                 account:[self keychainAccount]
                                   error:&error];
    return error;
}

- (NSError *)saveToKeychain {
    NSError *error = nil;
    [YYKeychain setPassword:[self modelToJSONString]
                 forService:[self.class keychainService]
                    account:[self.class keychainAccount]
                      error:&error];
    return error;
}

#pragma mark - keychain

+ (NSString *)keychainService {
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:(__bridge NSString *)kCFBundleIdentifierKey];
}

+ (NSString *)keychainAccount {
    return [NSString stringWithFormat:@"%@.currentUser", [self keychainService]];
}

@end
