//
//  WaterMarkView.m
//  ScreenCapture
//
//  Created by gunmm on 2020/1/14.
//  Copyright © 2020 minzhe. All rights reserved.
//

#import "WaterMarkView.h"

@interface WaterMarkView ()

@property (nonatomic, assign) CGPoint textBtnCenterPoint;
@property (nonatomic, assign) CGPoint textPanBeginPoint;

@property (nonatomic, assign) CGPoint rotateBtnCenterPoint;
@property (nonatomic, assign) CGPoint rotateBtnBeginPoint;
@end

@implementation WaterMarkView


- (void)awakeFromNib {
    [super awakeFromNib];
    self.deleteBtn.layer.cornerRadius = 10;
    self.deleteBtn.layer.masksToBounds = YES;
    self.rotateBtn.layer.cornerRadius = 10;
    self.rotateBtn.layer.masksToBounds = YES;
    self.textLabel.layer.borderColor = [UIColor whiteColor].CGColor;
    self.textLabel.layer.borderWidth = 1;
    
    UIPanGestureRecognizer *textBtnPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(textBtnPan:)];
    [self.textLabel addGestureRecognizer:textBtnPan];
    
    UIPanGestureRecognizer *rotatePan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onScaleAndRotate:)];
    [self.rotateBtn addGestureRecognizer:rotatePan];
}

- (void)textBtnPan:(UIPanGestureRecognizer *)pan
{
    CGPoint p = [pan translationInView:self.superview];
    if (pan.state == UIGestureRecognizerStateBegan) {
        self.textBtnCenterPoint = self.center;
        self.textPanBeginPoint = p;
        
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        CGFloat xDis = p.x - self.textPanBeginPoint.x;
        CGFloat yDis = p.y - self.textPanBeginPoint.y;
        self.center = CGPointMake(self.textBtnCenterPoint.x + xDis, self.textBtnCenterPoint.y + yDis);
    }
    else if (pan.state == UIGestureRecognizerStateEnded){
    }
}

- (void)onScaleAndRotate:(UIPanGestureRecognizer*)gesture
{
    UIView *viewCtrl = gesture.view;
    UIView *viewImg = self;
    
    CGPoint center = viewImg.center;
    CGPoint prePoint = [self convertPoint:viewCtrl.center toView:self.superview];
    CGPoint translation = [gesture translationInView:self.superview];
    CGPoint curPoint = CGPointMake(prePoint.x+translation.x, prePoint.y+translation.y);
    
    // 计算缩放
    CGFloat preDistance = [self getDistance:prePoint withPointB:center];
    CGFloat curDistance = [self getDistance:curPoint withPointB:center];
    CGFloat scale = curDistance / preDistance;
    CGFloat deScale = preDistance / curDistance;

    // 计算弧度
    CGFloat preRadius = [self getRadius:center withPointB:prePoint];
    CGFloat curRadius = [self getRadius:center withPointB:curPoint];
    CGFloat radius = curRadius - preRadius;
    radius = - radius;
    
    CGAffineTransform transform = CGAffineTransformScale(viewImg.transform, scale, scale);
    viewImg.transform = CGAffineTransformRotate(transform, radius);
    
    self.rotateBtn.transform = CGAffineTransformScale(self.rotateBtn.transform, deScale, deScale);
    self.deleteBtn.transform = CGAffineTransformScale(self.deleteBtn.transform, deScale, deScale);

    [gesture setTranslation:CGPointZero inView:viewCtrl];
}

- (CGFloat)getDistance:(CGPoint)pointA withPointB:(CGPoint)pointB
{
    CGFloat x = pointA.x - pointB.x;
    CGFloat y = pointA.y - pointB.y;
    return sqrt(x*x + y*y);
}

- (CGFloat)getRadius:(CGPoint)pointA withPointB:(CGPoint)pointB
{
    CGFloat x = pointA.x - pointB.x;
    CGFloat y = pointA.y - pointB.y;
    return atan2(x, y);
}

- (IBAction)deleteBtnAct:(id)sender {
    [self removeFromSuperview];
}

@end
