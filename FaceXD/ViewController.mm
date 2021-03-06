#import <ARKit/ARKit.h>
#import <SceneKit/SceneKit.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <Vision/Vision.h>
#import "MPControlValueLinear.h"

#import "CubismModelMatrix.hpp"
#import "ViewController.h"
#import "LAppModel.h"
#import "LAppBundle.h"
#import "LAppOpenGLManager.h"

#import "GCDAsyncSocket.h"

@interface ViewController () <ARSessionDelegate,ARSCNViewDelegate,GCDAsyncSocketDelegate>
@property (weak, nonatomic) IBOutlet UILabel *labelJson;
@property (weak, nonatomic) IBOutlet UISwitch *captureSwitch;
@property (weak, nonatomic) IBOutlet UIButton *resetButton;
@property (weak, nonatomic) IBOutlet UISwitch *startSwitch;
@property (weak, nonatomic) IBOutlet UILabel *timeStampLabel;
@property (weak, nonatomic) IBOutlet UISwitch *submitSwitch;
@property (weak, nonatomic) IBOutlet UILabel *faceCaptureStatusLabel;
@property (weak, nonatomic) IBOutlet UILabel *submitStatusLabel;
@property (weak, nonatomic) IBOutlet UISwitch *fpsSwitch;
@property (weak, nonatomic) IBOutlet UITextField *submitCaptureAddress;
@property (weak, nonatomic) IBOutlet UITextField *submitSocketPort;
@property (weak, nonatomic) IBOutlet UISwitch *startSubmitSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *useSocketSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *jsonSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *cameraSwitch;
@property (weak, nonatomic) IBOutlet UILabel *appVersionLabel;
@property (nonatomic, strong) GCDAsyncSocket *socket;
@property (weak, nonatomic) IBOutlet UISwitch *advancedSwitch;
@property (weak, nonatomic) IBOutlet ARSCNView *sceneView;

@property (nonatomic, assign) CGFloat headYaw;
@property (nonatomic, assign) CGFloat headPitch;
@property (nonatomic, assign) CGFloat headRoll;
@property (nonatomic, assign) CGFloat mouthOpenY;
@property (nonatomic, assign) CGFloat mouthForm;
@property (nonatomic, assign) CGFloat eyeLOpen;
@property (nonatomic, assign) CGFloat eyeROpen;
@property (nonatomic, assign) CGFloat eyeBrowYL;
@property (nonatomic, assign) CGFloat eyeBrowYR;
@property (nonatomic, assign) CGFloat eyeBrowAngleL;
@property (nonatomic, assign) CGFloat eyeBrowAngleR;
@property (nonatomic, assign) CGFloat eyeX;
@property (nonatomic, assign) CGFloat eyeY;
@property (nonatomic, assign) CGFloat bodyX;
@property (nonatomic, assign) CGFloat bodyY;
@property (nonatomic, assign) CGFloat bodyAngleX;
@property (nonatomic, assign) CGFloat bodyAngleY;
@property (nonatomic, assign) CGFloat bodyAngleZ;

@property (nonatomic) GLKView *glView;
@property (nonatomic, strong) LAppModel *hiyori;
@property (nonatomic, assign) CGSize screenSize;
@property (nonatomic, assign) NSInteger expressionCount;

@property (nonatomic, strong) ARSCNView *arSCNView;
@property (nonatomic, strong) ARSession *arSession;
@property (nonatomic, strong) SCNNode *faceNode;
@property (nonatomic, strong) SCNNode *leftEyeNode;
@property (nonatomic, strong) SCNNode *rightEyeNode;

@property (nonatomic, strong) MPControlValueLinear *eyeLinearX;
@property (nonatomic, strong) MPControlValueLinear *eyeLinearY;

@end

@implementation ViewController

- (GLKView *)glView {
    return (GLKView *)self.view;
}

- (SCNNode *)faceNode {
    if (_faceNode == nil) {
        _faceNode = [SCNNode node];
    }
    return _faceNode;
}

- (SCNNode *)leftEyeNode {
    if (_leftEyeNode == nil) {
        _leftEyeNode = [SCNNode node];
    }
    return _leftEyeNode;
}

- (SCNNode *)rightEyeNode {
    if (_rightEyeNode == nil) {
        _rightEyeNode = [SCNNode node];
    }
    return _rightEyeNode;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.submitCaptureAddress.delegate = self;
    self.submitSocketPort.delegate = self;
    
    self.screenSize = [[UIScreen mainScreen] bounds].size;
    
    [self.glView setContext:LAppGLContext];
    LAppGLContextAction(^{
        self.hiyori = [[LAppModel alloc] initWithName:@"Hiyori"];
        [self.hiyori loadAsset];
    
        //self.expressionCount = self.hiyori.expressionName.count;
        self.eyeLinearX = [[MPControlValueLinear alloc] initWithOutputMax:[self.hiyori paramMaxValue:LAppParamEyeBallX].doubleValue
                                                               outputMin:[self.hiyori paramMinValue:LAppParamEyeBallX].doubleValue
                                                                inputMax:45
                                                                inputMin:-45];
        self.eyeLinearY = [[MPControlValueLinear alloc] initWithOutputMax:[self.hiyori paramMaxValue:LAppParamEyeBallY].doubleValue
                                                                outputMin:[self.hiyori paramMinValue:LAppParamEyeBallY].doubleValue
                                                                 inputMax:45
                                                                 inputMin:-45];
        [self.hiyori startBreath];
    });
    
    
    [self loadConfig];
    
    [self setupARSession];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusBarOrientationChange:)name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
}

- (void)statusBarOrientationChange:(NSNotification *)notification{
    //需要修复旋转模型错位的问题
    /*UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    if (orientation == UIInterfaceOrientationLandscapeRight){
        NSLog(@"right");
    }
    if (orientation == UIInterfaceOrientationLandscapeLeft) {
        NSLog(@"left");
    }
    if (orientation == UIInterfaceOrientationPortrait){
        NSLog(@"1");
    }
    if (orientation == UIInterfaceOrientationPortraitUpsideDown){
        NSLog(@"2");
    }*/
}

- (void)loadConfig {
    NSString *Version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *Build   = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    self.appVersionLabel.text = [NSString stringWithFormat:@"%@ b%@", Version, Build];
    NSLog(NSLocalizedString(@"startupLog", nil) , Version, Build);
    
    NSUserDefaults *accountDefaults = [NSUserDefaults standardUserDefaults];
    if([accountDefaults objectForKey: @"submitAddress"] == nil){
        [accountDefaults setObject:@"http://127.0.0.1:12345" forKey: @"submitAddress"];
        [accountDefaults synchronize];
    }
    if([accountDefaults objectForKey: @"submitSocketPort"] == nil){
        [accountDefaults setObject:@"8040" forKey: @"submitSocketPort"];
        [accountDefaults synchronize];
    }
    self.submitCaptureAddress.text = [accountDefaults objectForKey: @"submitAddress"];
    self.submitSocketPort.text = [accountDefaults objectForKey: @"submitSocketPort"];
    self.fpsSwitch.on = [accountDefaults boolForKey: @"fpsSwitch"];
    self.jsonSwitch.on = [accountDefaults boolForKey: @"jsonSwitch"];
    if(self.jsonSwitch.on == 1){
        self.labelJson.hidden = 0;
    }
    self.useSocketSwitch.on = [accountDefaults boolForKey: @"useSocketSwitch"];
    self.advancedSwitch.on = [accountDefaults boolForKey: @"advancedSwitch"];
    
    //self.sceneView.showsStatistics = YES;
    self.sceneView.autoenablesDefaultLighting = YES;
    self.sceneView.debugOptions = SCNDebugOptionNone;
    
    SCNScene *scene = [SCNScene new];
    self.sceneView.scene = scene;
    self.sceneView.hidden = 1;
}

- (void)setupARSession {
    self.arSession = [[ARSession alloc] init];
    ARFaceTrackingConfiguration *faceTracking = [[ARFaceTrackingConfiguration alloc] init];
    faceTracking.worldAlignment = ARWorldAlignmentCamera;
    self.arSession.delegate = self;
    [self.arSession runWithConfiguration:faceTracking];
    self.sceneView.session = self.arSession;
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    [LAppOpenGLManagerInstance updateTime];
    
    glClear(GL_COLOR_BUFFER_BIT);
    [self.hiyori setMVPMatrixWithSize:self.screenSize];
    [self.hiyori onUpdateWithParameterUpdate:^{
        [self.hiyori setParam:LAppParamAngleX forValue:@(self.headYaw)];
        [self.hiyori setParam:LAppParamAngleY forValue:@(self.headPitch)];
        [self.hiyori setParam:LAppParamAngleZ forValue:@(self.headRoll)];
        [self.hiyori setParam:LAppParamMouthOpenY forValue:@(self.mouthOpenY)];
        [self.hiyori setParam:LAppParamMouthForm forValue:@(self.mouthForm)];
        [self.hiyori setParam:LAppParamEyeLOpen forValue:@(self.eyeLOpen)];
        [self.hiyori setParam:LAppParamEyeROpen forValue:@(self.eyeROpen)];
        [self.hiyori setParam:LAppParamEyeBrowLOpen forValue:@(self.eyeBrowYL)];
        [self.hiyori setParam:LAppParamEyeBrowROpen forValue:@(self.eyeBrowYR)];
        [self.hiyori setParam:LAppParamEyeBrowLAngle forValue:@(self.eyeBrowAngleL)];
        [self.hiyori setParam:LAppParamEyeBrowRAngle forValue:@(self.eyeBrowAngleR)];
        [self.hiyori setParam:LAppParamEyeBallX forValue:@(self.eyeX)];
        [self.hiyori setParam:LAppParamEyeBallY forValue:@(self.eyeY)];
        [self.hiyori setParam:LAppParamBodyAngleX forValue:@(self.bodyAngleX)];
        [self.hiyori setParam:LAppParamBodyAngleY forValue:@(self.bodyAngleY)];
        [self.hiyori setParam:LAppParamBodyAngleZ forValue:@(self.bodyAngleZ)];
    }];
    glClearColor(0, 1, 0, 1);
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    /*if (self.expressionCount == 0) return;
    static NSInteger index = 0;
    index += 1;
    if (index == self.expressionCount) {
        index = 0;
    }
    [self.hiyori startExpressionWithName:self.hiyori.expressionName[index]];*/
}

#pragma mark - Action

- (IBAction)handleResetButton:(id)sender {
    self.captureSwitch.on = 0;
    self.labelJson.text = NSLocalizedString(@"jsonData", nil);
    self.headPitch = 0;
    self.headYaw = 0;
    self.headRoll = 0;
    self.bodyAngleX = 0;
    self.bodyAngleY = 0;
    self.bodyAngleZ = 0;
    self.eyeLOpen = 0;
    self.eyeROpen = 0;
    self.eyeX = 0;
    self.eyeY = 0;
    self.mouthOpenY = 0;
    self.faceCaptureStatusLabel.text = NSLocalizedString(@"waiting", nil);
    self.submitStatusLabel.text = NSLocalizedString(@"stopped", nil);
    self.timeStampLabel.text = NSLocalizedString(@"timeStamp", nil);
}

- (IBAction)handleFaceCaptureSwitch:(id)sender {
    if(self.captureSwitch.on == 0){
        self.faceCaptureStatusLabel.text = NSLocalizedString(@"waiting", nil);
    }else{
        self.faceCaptureStatusLabel.text = NSLocalizedString(@"capturing", nil);
    }
}

- (IBAction)handleSubmitSwitch:(id)sender {
    if(self.submitSwitch.on == 0){
        if (self.socket.isConnected){
            [self.socket disconnect];
            self.socket = nil;
        }
        self.submitStatusLabel.text = NSLocalizedString(@"stopped", nil);
        self.useSocketSwitch.enabled = 1;
        socketTag = 0;
        [UIApplication sharedApplication].idleTimerDisabled = NO;
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    }else{
        if(self.useSocketSwitch.on == 1){
            self.submitSwitch.enabled = 0;
            if (self.socket == nil){
                self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_global_queue(0, 0)];
            }
            if (self.socket.isConnected){
                [self.socket disconnect];
                self.socket = nil;
            }
            NSError *error;
            if([self isValidatIP:self.submitCaptureAddress.text]
               && 0 < [self.submitSocketPort.text intValue]
               && [self.submitSocketPort.text intValue] < 25565
            ){
                [self.socket connectToHost:self.submitCaptureAddress.text onPort:[self.submitSocketPort.text intValue] withTimeout:5 error:&error];
                if (error) {
                    [self alertError:error.localizedDescription];
                    self.submitStatusLabel.text = NSLocalizedString(@"stopped", nil);
                    self.submitSwitch.on = 0;
                    self.submitSwitch.enabled = 1;
                    socketTag = 0;
                    [UIApplication sharedApplication].idleTimerDisabled = NO;
                    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                }
            }else{
                [self alertError: NSLocalizedString(@"illegalAddress", nil)];
                self.submitStatusLabel.text = NSLocalizedString(@"stopped", nil);
                self.submitSwitch.on = 0;
                self.submitSwitch.enabled = 1;
                socketTag = 0;
                [UIApplication sharedApplication].idleTimerDisabled = NO;
                [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
            }
        }else{
            self.useSocketSwitch.enabled = 0;
            if (self.socket.isConnected){
                [self.socket disconnect];
                self.socket = nil;
            }
            socketTag = 0;
            self.submitStatusLabel.text = NSLocalizedString(@"started", nil);
            [UIApplication sharedApplication].idleTimerDisabled =YES;
            [UIApplication sharedApplication].networkActivityIndicatorVisible =YES;
        }
    }
}

- (IBAction)handleJsonSwitch:(id)sender {
    NSUserDefaults *accountDefaults = [NSUserDefaults standardUserDefaults];
    if(self.jsonSwitch.on == 0){
        self.labelJson.hidden = 1;
        [accountDefaults setBool:NO forKey:@"jsonSwitch"];
    }else{
        self.labelJson.hidden = 0;
        [accountDefaults setBool:YES forKey:@"jsonSwitch"];
    }
    [accountDefaults synchronize];
}

- (IBAction)handleAdvancedSwitch:(id)sender {
    NSUserDefaults *accountDefaults = [NSUserDefaults standardUserDefaults];
    if(self.advancedSwitch.on == 0){
        [accountDefaults setBool:NO forKey:@"advancedSwitch"];
    }else{
        [accountDefaults setBool:YES forKey:@"advancedSwitch"];
    }
    [accountDefaults synchronize];
}

- (IBAction)handleCameraSwitch:(id)sender {
    if(self.cameraSwitch.on == 0){
        self.sceneView.hidden = 1;
    }else{
        self.sceneView.hidden = 0;
    }
}

-(BOOL)checkSocketAddress:(NSArray*)array {
    if([array count] == 2){
        NSScanner* scan = [NSScanner scannerWithString:[array objectAtIndex:1]];
        int val;
        if([self isValidatIP:[array objectAtIndex:0]] && ([scan scanInt:&val] && [scan isAtEnd])){
            if(0 < [[array objectAtIndex:1] intValue] && [[array objectAtIndex:1] intValue] < 25565){
                return true;
            }
        }
    }
    return false;
}

-(BOOL)isValidatIP:(NSString *)ipAddress{
    
    NSString  *urlRegEx =@"^([01]?\\d\\d?|2[0-4]\\d|25[0-5])\\."
                        "([01]?\\d\\d?|2[0-4]\\d|25[0-5])\\."
                        "([01]?\\d\\d?|2[0-4]\\d|25[0-5])\\."
                        "([01]?\\d\\d?|2[0-4]\\d|25[0-5])$";
    
    NSPredicate *urlTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", urlRegEx];
    return [urlTest evaluateWithObject:ipAddress];

}

- (void)alertError:(NSString*)data {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"errorTitle", nil)
                                                                       message:data
                                                                preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"errorOK", nil) style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * action) {
                                                                  //响应事件
                                                                  //NSLog(@"action = %@", action);
                                                              }];
    [alert addAction:cancelAction];
    [self presentViewController:alert animated:YES completion:nil];

}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(nonnull NSString *)host port:(uint16_t)port{
    NSLog(NSLocalizedString(@"socketConnected", nil), host, port);
    dispatch_async(dispatch_get_main_queue(), ^{
        self.useSocketSwitch.enabled = 0;
        self.submitSwitch.enabled = 1;
        self.submitStatusLabel.text = NSLocalizedString(@"started", nil);
        [UIApplication sharedApplication].idleTimerDisabled =YES;
        [UIApplication sharedApplication].networkActivityIndicatorVisible =YES;
    });
    //连接成功或者收到消息，必须开始read，否则将无法收到消息,
    //不read的话，缓存区将会被关闭
    // -1 表示无限时长 ,永久不失效
    [self.socket readDataWithTimeout:-1 tag:10086];
}

// 连接断开
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err{
    NSLog(NSLocalizedString(@"socketDisonnected", nil), err);
    socketTag = 0;
    if(err != nullptr){
        dispatch_async(dispatch_get_main_queue(), ^{
            [self alertError:err.localizedDescription];
            self.submitStatusLabel.text = NSLocalizedString(@"stopped", nil);
            self.submitSwitch.on = 0;
            self.submitSwitch.enabled = 1;
            self.useSocketSwitch.enabled = 1;
            [UIApplication sharedApplication].idleTimerDisabled = NO;
            [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        });
    }
}

//已经接收服务器返回来的数据
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{
    NSLog(NSLocalizedString(@"socketReceived", nil), tag, data.length);
    //连接成功或者收到消息，必须开始read，否则将无法收到消息
    //不read的话，缓存区将会被关闭
    // -1 表示无限时长 ， tag
    [self.socket readDataWithTimeout:-1 tag:10086];
}

//消息发送成功 代理函数 向服务器 发送消息
- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag{
    NSLog(NSLocalizedString(@"socketSent", nil),tag);
}

- (IBAction)handleFpsSwitch:(id)sender {
    NSUserDefaults *accountDefaults = [NSUserDefaults standardUserDefaults];
    if(self.fpsSwitch.on == 0){
        [accountDefaults setBool:NO forKey:@"fpsSwitch"];
    }else{
        [accountDefaults setBool:YES forKey:@"fpsSwitch"];
    }
    [accountDefaults synchronize];
}

- (IBAction)handleSocketSwitch:(id)sender {
    NSUserDefaults *accountDefaults = [NSUserDefaults standardUserDefaults];
    if(self.useSocketSwitch.on == 0){
        [accountDefaults setBool:NO forKey:@"useSocketSwitch"];
    }else{
        [accountDefaults setBool:YES forKey:@"useSocketSwitch"];
    }
    [accountDefaults synchronize];
}

- (IBAction)onAddressExit:(UITextField *)sender {
    NSUserDefaults *accountDefaults = [NSUserDefaults standardUserDefaults];
    [accountDefaults setObject:sender.text forKey: @"submitAddress"];
    [accountDefaults synchronize];
    [sender resignFirstResponder];
}

- (IBAction)onSocketPortExit:(UITextField *)sender {
    NSUserDefaults *accountDefaults = [NSUserDefaults standardUserDefaults];
    [accountDefaults setObject:sender.text forKey: @"submitSocketPort"];
    [accountDefaults synchronize];
    [sender resignFirstResponder];
}


#pragma mark - Delegate
#pragma mark - ARSCNViewDelegate
#pragma mark - ARSessionDelegate

- (ARSCNView *)arSCNView{
    if (!_arSCNView) {
        _arSCNView = [[ARSCNView alloc] initWithFrame:self.view.bounds];
        _arSCNView.delegate = self;
        _arSCNView.session = self.arSession;
    }
    return _arSCNView;
}

- (void)session:(ARSession *)session didUpdateAnchors:(NSArray<__kindof ARAnchor *> *)anchors {
    if(self.captureSwitch.on == 1){
        ARFaceAnchor *faceAnchor = anchors.firstObject;
        if (faceAnchor) {
            UInt64 recordTime = [[NSDate date] timeIntervalSince1970]*1000;

            NSString*timeString = [NSString stringWithFormat:@"%llu", recordTime];
            NSString*lastTimeString = [NSString stringWithFormat:@"%llu", lastRecordTime];
            
            if(self.fpsSwitch.on == 1){
                if((recordTime - lastRecordTime) < timeInOneFps){
                    //self.timeStampLabel.text = @"跳过本数据";
                    return;
                }else{
                    lastRecordTime = recordTime;
                    self.timeStampLabel.text = [NSString stringWithFormat:NSLocalizedString(@"30FPSLabel", nil), lastTimeString, timeString];
                }
            }else{
                self.timeStampLabel.text = [NSString stringWithFormat:NSLocalizedString(@"60FPSLabel", nil), timeString];
            }
            
            self.faceNode.simdTransform = faceAnchor.transform;
            if (@available(iOS 12.0, *)) {
                self.leftEyeNode.simdTransform = faceAnchor.leftEyeTransform;
                self.rightEyeNode.simdTransform = faceAnchor.rightEyeTransform;
            }
            
            self.headPitch = -(180 / M_PI) * self.faceNode.eulerAngles.x * 1.3;
            self.headYaw = (180 / M_PI) * self.faceNode.eulerAngles.y;
            self.headRoll = -(180 / M_PI) * self.faceNode.eulerAngles.z + 90.0;
            //横屏，roll+-90
            UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
            switch (orientation) {
                    case UIInterfaceOrientationLandscapeRight:
                        self.headRoll = self.headRoll - 90;
                        break;

                    case UIInterfaceOrientationLandscapeLeft:
                        //实在不知道怎么算了。。。
                        self.headRoll = - asin(faceAnchor.transform.columns[1].x) * 40;
                        break;
                    case UIInterfaceOrientationPortraitUpsideDown:
                        self.headRoll = self.headRoll - 180;
                        break;
                    default:
                        break;
                
            }
        
            self.bodyAngleX = self.headYaw / 4;
            self.bodyAngleY = self.headPitch / 2;
            self.bodyAngleZ = self.headRoll / 2;
            
            self.eyeLOpen = 1 - faceAnchor.blendShapes[ARBlendShapeLocationEyeBlinkLeft].floatValue * 1.3;
            self.eyeROpen = 1 - faceAnchor.blendShapes[ARBlendShapeLocationEyeBlinkRight].floatValue * 1.3;
            self.eyeX = [self.eyeLinearX calc:(180 / M_PI) * self.leftEyeNode.eulerAngles.y];
            self.eyeY = - [self.eyeLinearY calc:(180 / M_PI) * self.leftEyeNode.eulerAngles.x];
            self.mouthOpenY = faceAnchor.blendShapes[ARBlendShapeLocationJawOpen].floatValue * 1.8;
            
            CGFloat innerUp = faceAnchor.blendShapes[ARBlendShapeLocationBrowInnerUp].floatValue;
            CGFloat outerUpL = faceAnchor.blendShapes[ARBlendShapeLocationBrowOuterUpLeft].floatValue;
            CGFloat outerUpR = faceAnchor.blendShapes[ARBlendShapeLocationBrowOuterUpRight].floatValue;
            CGFloat downL = faceAnchor.blendShapes[ARBlendShapeLocationBrowDownLeft].floatValue;
            CGFloat downR = faceAnchor.blendShapes[ARBlendShapeLocationBrowDownRight].floatValue;
            self.eyeBrowYL = (innerUp + outerUpL) / 2;
            self.eyeBrowYR = (innerUp + outerUpR) / 2;
            self.eyeBrowAngleL = 17*(innerUp - outerUpL) - downL - 2.5;
            self.eyeBrowAngleR = 17*(innerUp - outerUpR) - downR - 2.5;
            CGFloat mouthFunnel = faceAnchor.blendShapes[ARBlendShapeLocationMouthFunnel].floatValue;
            CGFloat mouthLeft = faceAnchor.blendShapes[ARBlendShapeLocationMouthFrownLeft].floatValue;
            CGFloat mouthRight = faceAnchor.blendShapes[ARBlendShapeLocationMouthFrownRight].floatValue;
            CGFloat mouthSmileLeft = faceAnchor.blendShapes[ARBlendShapeLocationMouthSmileLeft].floatValue;
            CGFloat mouthSmileRight = faceAnchor.blendShapes[ARBlendShapeLocationMouthSmileRight].floatValue;
            CGFloat mouthForm = 0 - (mouthLeft - mouthSmileLeft + mouthRight - mouthSmileRight) / 2 * 8 - 1 / 3;
            if(mouthForm < 0){
                mouthForm = mouthForm - mouthFunnel;
            }
            self.mouthForm = mouthForm;
            NSDictionary *param = @{
                            @"headPitch"       : [NSString stringWithFormat: @"%.5lf", self.headPitch],
                            @"headYaw"         : [NSString stringWithFormat: @"%.5lf", self.headYaw],
                            @"headRoll"        : [NSString stringWithFormat: @"%.5lf", self.headRoll],
                            @"bodyAngleX"      : [NSString stringWithFormat: @"%.5lf", self.bodyAngleX],
                            @"bodyAngleY"      : [NSString stringWithFormat: @"%.5lf", self.bodyAngleY],
                            @"bodyAngleZ"      : [NSString stringWithFormat: @"%.5lf", self.bodyAngleZ],
                            @"eyeLOpen"        : [NSString stringWithFormat: @"%.5lf", self.eyeLOpen],
                            @"eyeROpen"        : [NSString stringWithFormat: @"%.5lf", self.eyeROpen],
                            @"eyeBrowYL"       : [NSString stringWithFormat: @"%.5lf", self.eyeBrowYL],
                            @"eyeBrowYR"       : [NSString stringWithFormat: @"%.5lf", self.eyeBrowYR],
                            @"eyeBrowAngleL"   : [NSString stringWithFormat: @"%.5lf", self.eyeBrowAngleL],
                            @"eyeBrowAngleR"   : [NSString stringWithFormat: @"%.5lf", self.eyeBrowAngleR],
                            @"eyeX"            : [NSString stringWithFormat: @"%.5lf", self.eyeX],
                            @"eyeY"            : [NSString stringWithFormat: @"%.5lf", self.eyeY],
                            @"mouthOpenY"      : [NSString stringWithFormat: @"%.5lf", self.mouthOpenY],
                            @"mouthForm"       : [NSString stringWithFormat: @"%.5lf", self.mouthForm],
                            @"timeStamp"       : timeString,
            };
            if(self.advancedSwitch.on == 1){
                param = faceAnchor.blendShapes;
            }
            NSError *parseError = nil;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:param options:NSJSONWritingPrettyPrinted error:&parseError];
            NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            if (!jsonData) {
                NSLog(@"%@",parseError);
            }else{
                NSMutableString *mutStr = [NSMutableString stringWithString:jsonString];

                NSRange range = {0,jsonString.length};
                [mutStr replaceOccurrencesOfString:@" " withString:@"" options:NSLiteralSearch range:range];
                NSRange range2 = {0,mutStr.length};
                [mutStr replaceOccurrencesOfString:@"\n" withString:@"" options:NSLiteralSearch range:range2];
                NSMutableString *mutStrShow = mutStr;
                NSRange range3 = {0,mutStrShow.length};
                [mutStrShow replaceOccurrencesOfString:@"," withString:@",\n" options:NSLiteralSearch range:range3];
                self.labelJson.text = mutStrShow;
                if(self.startSubmitSwitch.on == 1){
                    if(self.useSocketSwitch.on == 0){
                        [self postJson:mutStr];
                    }else{
                        [self postSocket:mutStr];
                    }
                }
            }
        }
    }
}

- (void)postJson:(NSString*)data {
    NSURLSession *session = [NSURLSession sharedSession];
    NSURL *url = [NSURL URLWithString:self.submitCaptureAddress.text];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.HTTPBody = [[NSString stringWithFormat:@"jsonData=%s", [data UTF8String]] dataUsingEncoding:NSUTF8StringEncoding];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        //NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
        //NSLog(@"%@",dict);
        
    }];
    [dataTask resume];
}

- (void)postSocket:(NSString*)dataJson {
    if(self.socket.isConnected){
        NSData *data = [dataJson dataUsingEncoding:NSUTF8StringEncoding];
        //NSUInteger size = data.length;
        //NSData *lengthData = [[NSString stringWithFormat:@"[length=%ld]",size] dataUsingEncoding:NSUTF8StringEncoding];
        //NSMutableData *mData = [NSMutableData dataWithData:lengthData];
        //[mData appendData:data];
        //NSLog(@"%d", socketTag);
        socketTag += 1;
        [self.socket writeData:data withTimeout:-1 tag:socketTag];
    }
}

@end
