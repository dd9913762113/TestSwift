//
//  DK_SGWiFiUploadVC.m
//  3332323
//
//  Created by dd on 14/4/22.
//  Copyright © 2022 XJW. All rights reserved.
//

#import "DK_SGWiFiUploadVC.h"
#import "SGWiFiUploadManager.h"
#import "LFPhoneInfo.h"

#define kLabelCount 26

@interface DK_SGWiFiUploadVC ()


//ScrollView
@property (nonatomic, strong) UIScrollView *scrollView;

//存放显示标签的数组
@property (nonatomic, strong) NSMutableArray <UILabel *>*labelArray;

@end

@implementation DK_SGWiFiUploadVC


- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    
    [self createLabels];
    [self showPhoneInfo];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self setupServer];
}

- (void)setupServer {
    SGWiFiUploadManager *mgr = [SGWiFiUploadManager sharedManager];
    BOOL success = [mgr startHTTPServerAtPort:10086];
    if (success) {
        [mgr setFileUploadStartCallback:^(NSString *fileName, NSString *savePath) {
            NSLog(@"File %@ Upload Start", fileName);
        }];
        [mgr setFileUploadProgressCallback:^(NSString *fileName, NSString *savePath, CGFloat progress) {
            NSLog(@"File %@ on progress %f", fileName, progress);
        }];
        [mgr setFileUploadFinishCallback:^(NSString *fileName, NSString *savePath) {
            NSLog(@"File Upload Finish %@ at %@", fileName, savePath);
        }];
    }
    [mgr showWiFiPageFrontViewController:self dismiss:^{
        [mgr stopHTTPServer];
    }];
}




// 展示手机信息
-(void)showPhoneInfo{
    // 获取当前设备的具体型号字符串 e.g. @"iPhone X" @"iPhone XS" @"iPhone XS Max
    NSInteger i = 0;
    self.labelArray[i++].text = [NSString stringWithFormat:@"设备型号：%@",LFPhoneInfo.deviceTypeString];
    // 手机系统版本 e.g. @"9.3.5"
    self.labelArray[i++].text = [NSString stringWithFormat:@"设备系统版本：%@",LFPhoneInfo.deviceSystemVersion];
    // 手机系统名称 e.g. @"iOS"
    self.labelArray[i++].text = [NSString stringWithFormat:@"设备系统名称：%@",LFPhoneInfo.deviceSystemName];
    // 设备类型名称 e.g. @"iPhone", @"iPod touch", @"iPad"
    self.labelArray[i++].text = [NSString stringWithFormat:@"设备类型：%@",LFPhoneInfo.deviceModel];
    // 当前设备用户设置的名称，设置->通用->关于本机->名称 e.g. "My iPhone"
    self.labelArray[i++].text = [NSString stringWithFormat:@"设备用户名：%@",LFPhoneInfo.deviceSettingName];
    // 判断当前设备是不是iPhone，YES 是 iPhone 设备，NO不是
    self.labelArray[i++].text = [NSString stringWithFormat:@"是否是iPhone真机：%@",LFPhoneInfo.deviceIsIPhone?@"是":@"否"];
    // 判断当前设备是不是 iPhoneX 系列，YES 是 iPhoneX 系列，NO 不是
    self.labelArray[i++].text = [NSString stringWithFormat:@"是否是 iPhoneX 系列：%@",LFPhoneInfo.deviceIsIPhoneX?@"是":@"否"];
    // 判断当前设备是不是iPad，YES 是 iPad 设备，NO不是
    self.labelArray[i++].text = [NSString stringWithFormat:@"是否是iPad：%@",LFPhoneInfo.deviceIsIPad?@"是":@"否"];
    // 判断当前设备是不是iPod，YES 是 iPod 设备，NO不是
    self.labelArray[i++].text = [NSString stringWithFormat:@"是否是iPod：%@",LFPhoneInfo.deviceIsIPod?@"是":@"否"];
    // 判断当前设备是不是模拟器，YES 是 模拟器，NO不是
    self.labelArray[i++].text = [NSString stringWithFormat:@"是否是模拟器：%@",LFPhoneInfo.deviceIsSimulator?@"是":@"否"];
    // 当前设备电池电量百分比，取值范围 0 至 1.0，如果返回 -1.0 表示无法识别电池
    NSString *batteryLevel = [NSString stringWithFormat:@"当前电量：%d %%",(int)(LFPhoneInfo.deviceBatteryLevel * 100)];
    if (LFPhoneInfo.deviceBatteryLevel == -1) {
        batteryLevel = @"当前电量：无法识别电池🔋";
    }
    self.labelArray[i++].text = batteryLevel;
    // 屏幕逻辑尺寸 e.g. 逻辑像素尺寸为 2208x1242（屏幕实际物理像素尺寸是 1920x1080）
    self.labelArray[i++].text = [NSString stringWithFormat:@"屏幕逻辑尺寸：%@",NSStringFromCGSize(LFPhoneInfo.deviceLogicalScreenSize)];
    // 当前设备总内存, 返回值为兆 MB, e.g. iPhone 总内存为 2048 MB
    self.labelArray[i++].text = [NSString stringWithFormat:@"设备总内存：%.1f MB",LFPhoneInfo.deviceTotalMemory];
    // 当前 App 占用的设备内存，返回值为兆 MB, e.g. 占用 43 MB
    self.labelArray[i++].text = [NSString stringWithFormat:@"App占用内存：%.1f MB",LFPhoneInfo.appTakeUpMemory];
    // 当前磁盘总空间，返回值为兆 MB，0为异常 e.g. 总共 16 GB 即 16384 MB
    self.labelArray[i++].text = [NSString stringWithFormat:@"设备总存储：%.1f MB",LFPhoneInfo.deviceTotalDisk];
    // 当前磁盘未使用，返回值为兆 MB，0为异常 e.g. 空闲 2200 MB
    self.labelArray[i++].text = [NSString stringWithFormat:@"设备剩余存储：%.1f MB",LFPhoneInfo.deviceFreeDisk];
    // 当前磁盘已经使用，返回值为兆 MB，0为异常 e.g. 已使用 2200 MB
    self.labelArray[i++].text = [NSString stringWithFormat:@"设备已用存储：%.1f MB",LFPhoneInfo.deviceUsedDisk];
    // 通过系统框架获取设备运营商 e.g. @"中国移动" @"中国联通" @"中国电信"
    NSString *carrieName = LFPhoneInfo.deviceCarrierList.firstObject;
    if (LFPhoneInfo.deviceSIMCount > 1) {
        carrieName = [NSString stringWithFormat:@"%@,%@",LFPhoneInfo.deviceCarrierList.firstObject, LFPhoneInfo.deviceCarrierList.lastObject];
    }
    self.labelArray[i++].text = [NSString stringWithFormat:@"网络运营商：%@",carrieName];
    // 当前设备的 CPU 数量
    self.labelArray[i++].text = [NSString stringWithFormat:@"CPU 个数：%ld",(long)LFPhoneInfo.deviceCPUNum];
    // 当前 SIM 个数
    self.labelArray[i++].text = [NSString stringWithFormat:@"SIM 个数：%ld",(long)LFPhoneInfo.deviceSIMCount];
    // 当前设备网络状态 e.g. @"WiFi" @"无服务" @"2G" @"3G" @"4G" @"LTE" @"WWAN"
    self.labelArray[i++].text = [NSString stringWithFormat:@"网络状态：%@",LFPhoneInfo.deviceNetType];
    // 当前设备局域网 ip 地址
    self.labelArray[i++].text = [NSString stringWithFormat:@"局域网 IP 地址：%@",LFPhoneInfo.deviceLANIp];
    // 当前 APP 最近的一次更新时间(或安装时间) e.g. @"2019-06-01 12:32:38 +0000"
    self.labelArray[i++].text = [NSString stringWithFormat:@"App 更新时间：%@",LFPhoneInfo.appUpdateDate];
    // 当前设备是否越狱,模拟器会认为已经越狱
    self.labelArray[i++].text = [NSString stringWithFormat:@"是否越狱：%@",LFPhoneInfo.deviceIsJailbreak?@"是":@"否"];
    // 当前设备是否使用网络代理, YES 是使用，NO 为未使用
    self.labelArray[i++].text = [NSString stringWithFormat:@"是否使用代理：%@",LFPhoneInfo.deviceIsUseProxy?@"是":@"否"];
}

//创建label
-(void)createLabels{
    self.view.backgroundColor = [UIColor whiteColor];
    CGFloat labelH = 44;
    
    self.labelArray = [NSMutableArray arrayWithCapacity:kLabelCount];
    
    UIScrollView *sView = [[UIScrollView alloc]initWithFrame:self.view.bounds];
    [self.view addSubview:sView];
    self.scrollView = sView;
    
    for (NSInteger i = 0; i < kLabelCount; i++) {
        UILabel *tempLabel = [[UILabel alloc]init];
        [self.scrollView addSubview:tempLabel];
        tempLabel.font = [UIFont systemFontOfSize:11];
        tempLabel.numberOfLines = 0;
        tempLabel.frame = CGRectMake(15, labelH * i + 20, self.view.bounds.size.width - 30, labelH);
        [self.labelArray addObject:tempLabel];
    }
    CGFloat ContentH = kLabelCount * labelH + 10;
    self.scrollView.contentSize = CGSizeMake(0, ContentH);
}

@end
