//
//  PayManager.m
//  CaptureDeviceProject
//
//  Created by minzhe on 2019/12/27.
//  Copyright © 2019 minzhe. All rights reserved.
//

#import "PayManager.h"
#import <StoreKit/StoreKit.h>
#import "BaseDeviceManager.h"

@interface PayManager () <SKPaymentTransactionObserver, SKProductsRequestDelegate>

@end

@implementation PayManager

+ (instancetype)manager {
    static PayManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [PayManager new];
        [[SKPaymentQueue defaultQueue] addTransactionObserver:instance];
    });
    return instance;
}

- (void)dealloc
{
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

- (void)getRequestAppleProduct {
    NSArray *product = @[@"com.gunmm.amonth", @"com.gunmm.lifelong"];
    NSSet *nsset = [NSSet setWithArray:product];
    // 8.初始化请求
    SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:nsset];
    request.delegate = self;
    // 9.开始请求
    [request start];
}

#pragma mark ---SKProductsRequestDelegate
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    NSArray *product = response.products;
    //如果服务器没有产品
    if([product count] == 0){
        NSLog(@"nothing");
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        UserInfoKeyChain *userInfoKeyChain = [UserInfoKeyChain keychainInstance];
        
        UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"过期提醒" message:[NSString stringWithFormat:@"您的使用权限已于\n%@\n过期，请选择续期类型", [NavBgImage getTimestamp:userInfoKeyChain.expirationTime]]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        for (SKProduct *pro in product) {
            UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:[pro localizedTitle] style:UIAlertActionStyleDefault
                                                                  handler:^(UIAlertAction * action) {
                // 12.发送购买请求
                SKPayment *payment = [SKPayment paymentWithProduct:pro];
                [[SKPaymentQueue defaultQueue] addPayment:payment];
            }];
            [alert addAction:defaultAction];
        }
        [rootViewController presentViewController:alert animated:YES completion:nil];
    });
}

- (void)requestDidFinish:(SKRequest *)request {
    NSLog(@"信息反馈结束");
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    NSLog(@"error:%@", error);
}

#pragma mark ---SKPaymentTransactionObserver

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transaction {
    for(SKPaymentTransaction *tran in transaction){
        switch (tran.transactionState) {
            case SKPaymentTransactionStatePurchased:
                NSLog(@"交易完成");
                [self completeTransaction:tran];
                break;
            case SKPaymentTransactionStatePurchasing:
                NSLog(@"商品添加进列表");
                break;
            case SKPaymentTransactionStateRestored:
                NSLog(@"已经购买过商品");
                [[SKPaymentQueue defaultQueue] finishTransaction:tran];
                break;
            case SKPaymentTransactionStateFailed:
                NSLog(@"交易失败");
                [[SKPaymentQueue defaultQueue] finishTransaction:tran];
                break;
            default:
                break;
        }
    }
}


- (void)completeTransaction:(SKPaymentTransaction *)transaction
{
    NSString * str = [[NSString alloc]initWithData:transaction.transactionReceipt encoding:NSUTF8StringEncoding];
    
    NSString *environment=[self environmentForReceipt:str];
    NSLog(@"----- 完成交易调用的方法completeTransaction 1--------%@",environment);
    // 验证凭据，获取到苹果返回的交易凭据
    // appStoreReceiptURL iOS7.0增加的，购买交易完成后，会将凭据存放在该地址
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    // 从沙盒中获取到购买凭据
    NSData *receiptData = [NSData dataWithContentsOfURL:receiptURL];
    /**
     20      BASE64 常用的编码方案，通常用于数据传输，以及加密算法的基础算法，传输过程中能够保证数据传输的稳定性
     21      BASE64是可以编码和解码的
     22      */
    NSString *encodeStr = [receiptData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
    
    NSString *sendString = [NSString stringWithFormat:@"{\"receipt-data\" : \"%@\"}", encodeStr];
    NSLog(@"_____%@",sendString);
    NSURL *StoreURL=nil;
    if ([environment isEqualToString:@"environment=Sandbox"]) {
        StoreURL= [[NSURL alloc] initWithString: @"https://sandbox.itunes.apple.com/verifyReceipt"];
    }
    else{
        StoreURL= [[NSURL alloc] initWithString: @"https://buy.itunes.apple.com/verifyReceipt"];
    }
    //这个二进制数据由服务器进行验证；zl
    NSData *postData = [NSData dataWithBytes:[sendString UTF8String] length:[sendString length]];
    NSLog(@"++++++%@",postData);
    NSMutableURLRequest *connectionRequest = [NSMutableURLRequest requestWithURL:StoreURL];
    
    [connectionRequest setHTTPMethod:@"POST"];
    [connectionRequest setTimeoutInterval:50.0];//120.0---50.0zl
    [connectionRequest setCachePolicy:NSURLRequestUseProtocolCachePolicy];
    [connectionRequest setHTTPBody:postData];
    
    //开始请求
    NSError *error=nil;
    NSData *responseData=[NSURLConnection sendSynchronousRequest:connectionRequest returningResponse:nil error:&error];
    if (error) {
        NSLog(@"验证购买过程中发生错误，错误信息：%@",error.localizedDescription);
        return;
    }
    NSDictionary *dic=[NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingAllowFragments error:nil];
    NSLog(@"请求成功后的数据:%@",dic);
    //这里可以等待上面请求的数据完成后并且state = 0 验证凭据成功来判断后进入自己服务器逻辑的判断,也可以直接进行服务器逻辑的判断,验证凭据也就是一个安全的问题。楼主这里没有用state = 0 来判断。
    //  [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
    
    NSString *product = transaction.payment.productIdentifier;
    UserInfoKeyChain *userInfoKeyChain = [UserInfoKeyChain keychainInstance];
    
    long nowTimeLong = [[NSDate date] timeIntervalSince1970];
    long baseTimeLong = [userInfoKeyChain.expirationTime longValue];
    if (nowTimeLong > baseTimeLong) {
        baseTimeLong = nowTimeLong;
    }
    
    if ([product isEqualToString:@"com.gunmm.lifelong"]) {
        long expirationTimeLong = baseTimeLong + 50 * 365 * 24 * 3600;
        userInfoKeyChain.expirationTime = [NSString stringWithFormat:@"%ld", expirationTimeLong];
    } else {
        long expirationTimeLong = baseTimeLong + 31 * 24 * 3600;
        userInfoKeyChain.expirationTime = [NSString stringWithFormat:@"%ld", expirationTimeLong];
    }
    [userInfoKeyChain saveToKeychain];
    [BaseDeviceManager uploadDeviceInfo];
    
    NSMutableDictionary *paraDic = [NSMutableDictionary dictionaryWithDictionary:dic];
    [paraDic setObject:product forKey:@"product"];
    [BaseDeviceManager uploadPayData:paraDic];

    //此方法为将这一次操作上传给我本地服务器,记得在上传成功过后一定要记得销毁本次操作。调用[[SKPaymentQueue defaultQueue] finishTransaction: transaction];
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

-(NSString * )environmentForReceipt:(NSString * )str
{
    str= [str stringByReplacingOccurrencesOfString:@"\r\n" withString:@""];
    
    str = [str stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    
    str = [str stringByReplacingOccurrencesOfString:@"\t" withString:@""];
    
    str=[str stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    str=[str stringByReplacingOccurrencesOfString:@"\"" withString:@""];
    
    NSArray * arr=[str componentsSeparatedByString:@";"];
    
    //存储收据环境的变量
    NSString * environment=arr[2];
    return environment;
}

@end
