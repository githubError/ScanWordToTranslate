//
//  ViewController.m
//  test3
//
//  Created by cuipengfei on 16/8/22.
//  Copyright © 2016年 cuipengfei. All rights reserved.
//

#import "ViewController.h"
#import "TesseractOCR.h"
#import <CommonCrypto/CommonDigest.h>
#import "AFNetworking.h"
#import <AVFoundation/AVFoundation.h>

typedef void(^textFieldValueChanged)();

@interface ViewController ()<G8TesseractDelegate, UITextFieldDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>
{
    NSString *_transMode;   // 翻译模式
    
    UIImage *_scannedImage;
    
    BOOL isDisposing;
}

@property (nonatomic, strong) NSOperationQueue *operationQueue;
@property (nonatomic, strong) NSMutableDictionary *params;

@property (weak, nonatomic) IBOutlet UITextField *scanningTextField;
@property (weak, nonatomic) IBOutlet UITextField *scanResultTextField;
@property (weak, nonatomic) IBOutlet UISegmentedControl *transModeSegement;
@property (weak, nonatomic) IBOutlet UITextView *transResultTextView;
@property (weak, nonatomic) IBOutlet UIButton *changeDicButton;
@property (weak, nonatomic) IBOutlet UIProgressView *scanningProgressView;

@property (weak, nonatomic) IBOutlet UIImageView *testImageView;

@property (nonatomic, strong) textFieldValueChanged textFieldValueChangedBlock;


@property (nonatomic, retain) AVCaptureSession *captureSession;
@property (nonatomic, retain) AVCaptureVideoPreviewLayer *prevLayer;

@end

@implementation ViewController

#pragma mark - LazyLoading

- (AVCaptureSession *)captureSession {
    if (!_captureSession) {
        _captureSession = [[AVCaptureSession alloc] init];
    }
    return _captureSession;
}

- (AVCaptureVideoPreviewLayer *)prevLayer {
    if (!_prevLayer) {
        _prevLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
        _prevLayer.frame = self.view.bounds;
    }
    return _prevLayer;
}

#pragma mark - 界面设置
- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupView];
    
    [self setupCamera];
    
}

- (void)viewDidAppear:(BOOL)animated {
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(scannedImageChanged) name:@"scannedImageChanged" object:nil];
}

- (void)scannedImageChanged {
    
    isDisposing = YES;
    [self recognizeImageWithTesseract:_scannedImage transMode:_transMode];
    isDisposing = NO;
}

- (void)setupView {
    
    self.params = [NSMutableDictionary dictionary];
    _transMode = @"enTozh";
    isDisposing = NO;
    self.scanningTextField.enabled = NO;
    
    self.scanResultTextField.layer.borderColor = [UIColor whiteColor].CGColor;
    self.scanResultTextField.layer.borderWidth = 2.0f;
    self.scanResultTextField.backgroundColor = [UIColor whiteColor];
    self.scanResultTextField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 5, 0)];
    self.scanResultTextField.leftViewMode = UITextFieldViewModeAlways;
    self.scanResultTextField.clearButtonMode = UITextFieldViewModeAlways;
    
    [self.transModeSegement addTarget:self action:@selector(transModeSegementClick:) forControlEvents:UIControlEventValueChanged];
    
    [self.changeDicButton addTarget:self action:@selector(changeDic) forControlEvents:UIControlEventTouchUpInside];
    
}

- (void)setupCamera {
    
    
    AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput deviceInputWithDevice:[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo]  error:nil];
    
    AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc] init];
    
    captureOutput.alwaysDiscardsLateVideoFrames = YES;
    
    dispatch_queue_t queue = dispatch_queue_create("cameraQueue", NULL);
    
    [captureOutput setSampleBufferDelegate:self queue:queue];
    
    NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
    NSNumber* value = [NSNumber
                       numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
    NSDictionary* videoSettings = [NSDictionary
                                   dictionaryWithObject:value forKey:key];
    [captureOutput setVideoSettings:videoSettings];
    self.captureSession = [[AVCaptureSession alloc] init];
    [self.captureSession addInput:captureInput];
    [self.captureSession addOutput:captureOutput];
    
    self.prevLayer = [AVCaptureVideoPreviewLayer
                      layerWithSession: self.captureSession]; 
    self.prevLayer.frame = CGRectMake(0, 20, [UIScreen mainScreen].bounds.size.width, self.scanningTextField.frame.origin.y + 80);
    
    CALayer *layer = [[CALayer alloc] init];
    layer.frame = self.scanningTextField.frame;
    layer.borderColor = [UIColor blackColor].CGColor;
    layer.borderWidth = 2.0f;
    [self.prevLayer addSublayer:layer];
    
    self.prevLayer.videoGravity = AVLayerVideoGravityResizeAspectFill; 
    [self.view.layer addSublayer: self.prevLayer];
    
    [self.captureSession startRunning];
}


#pragma mark - 捕获扫描数据

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    
    if (isDisposing) return;
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    
    CGContextClipToRect(newContext, self.scanningTextField.frame);
    
    CGImageRef newImage = CGBitmapContextCreateImage(newContext);
    
    CGContextRelease(newContext);
    CGColorSpaceRelease(colorSpace);
    
    UIImage *image = [UIImage imageWithCGImage:newImage scale:1.0
                                  orientation:UIImageOrientationRight];
    

    _scannedImage = image;
    
    
    NSLog(@"-----%@",_scannedImage);
    self.testImageView.image = _scannedImage;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"scannedImageChanged" object:nil];

    CGImageRelease(newImage);
    
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
} 


#pragma mark - 翻译内容处理
-(void)recognizeImageWithTesseract:(UIImage *)image transMode:(NSString *)transMode
{
    
    self.operationQueue = [[NSOperationQueue alloc] init];
    if ([transMode isEqualToString:@"enTozh"]) {
        transMode = @"eng";
    }
    
    if ([transMode isEqualToString:@"zhToen"]) {
        transMode = @"chi_sim";
    }
    G8RecognitionOperation *operation = [[G8RecognitionOperation alloc] initWithLanguage:transMode];
    operation.tesseract.engineMode = G8OCREngineModeTesseractOnly;
    
    operation.tesseract.pageSegmentationMode = G8PageSegmentationModeAutoOnly;
    
    operation.delegate = self;
    
    operation.tesseract.image = image;
    
    __weak typeof(self) weakSelf = self;
    
    operation.recognitionCompleteBlock = ^(G8Tesseract *tesseract) {
        // Fetch the recognized text
        
        weakSelf.scanResultTextField.text = tesseract.recognizedText;
        
        [weakSelf textFieldChanged:^{ }];
    };
    
    [self.operationQueue addOperation:operation];
}

- (void)textFieldChanged:(textFieldValueChanged)textFieldValueChangedBlock {
    if (textFieldValueChangedBlock) {
        textFieldValueChangedBlock();
        [self transModeSegementClick:self.transModeSegement];
    }
}

- (void)transModeSegementClick:(UISegmentedControl *)segment {
    NSInteger index = segment.selectedSegmentIndex;
    switch (index) {
        case 0:
            _transMode = @"enTozh";
            isDisposing = YES;
            [self searchScannedResult:self.scanResultTextField.text fromLanguage:@"en" toLanguage:@"zh"];
            
            break;
        case 1:
            _transMode = @"zhToen";
            isDisposing = YES;
            [self searchScannedResult:self.scanResultTextField.text fromLanguage:@"zh" toLanguage:@"en"];
            break;
        default:
            break;
    }
}

- (void)searchScannedResult:(NSString *)scannedResult fromLanguage:(NSString *)from toLanguage:(NSString *)to{
    NSMutableString *salt = [NSMutableString string];
    for (int i = 0; i < 10; i++) {
        NSInteger num = arc4random() % 10;
        [salt appendString:[NSString stringWithFormat:@"%ld",(long)num]];
    }
    
    NSString *sign = [NSString stringWithFormat:@"20160822000027262%@%@ftjTy_1cU1bOUsO5qxd8",scannedResult,salt];
    sign = [self md5:sign];
    
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    
    params[@"q"] = scannedResult;
    params[@"from"] = from;
    params[@"to"] = to;
    params[@"appid"] = @(20160822000027262);
    params[@"salt"] = salt;
    params[@"sign"] = sign;
    
    [manager GET:@"http://api.fanyi.baidu.com/api/trans/vip/translate" parameters:params progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        NSArray *resultArr = responseObject[@"trans_result"];
        NSDictionary *dic = [resultArr firstObject];
        NSString *result = [NSString stringWithFormat:@"%@:\n\t%@",dic[@"src"],dic[@"dst"]];
        self.transResultTextView.text = result;
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
    }];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        isDisposing = NO;
    });
}

- (NSString *)md5:(NSString *)str
{
    const char *cStr = [str UTF8String];
    unsigned char result[16];
    CC_MD5(cStr, (CC_LONG)strlen(cStr), result); // This is the md5 call
    return [NSString stringWithFormat:
            @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
            ]; 
}

- (void)changeDic {
    
    UIReferenceLibraryViewController *refer = [[UIReferenceLibraryViewController alloc] initWithTerm:self.scanResultTextField.text];
    [self presentViewController:refer animated:YES completion:nil];
}

#pragma mark - G8TesseractDelegate

- (void)progressImageRecognitionForTesseract:(G8Tesseract *)tesseract {
    
    self.scanningProgressView.progress = 1.0 * (unsigned long)tesseract.progress / 100;
}

- (BOOL)shouldCancelImageRecognitionForTesseract:(G8Tesseract *)tesseract {
    return NO;  // return YES, if you need to cancel recognition prematurely
}


#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    
    [textField resignFirstResponder];
    
    [self transModeSegementClick:self.transModeSegement];
    
    return YES;
}

#pragma mark - 其他

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.scanResultTextField resignFirstResponder];
    [self.transResultTextView resignFirstResponder];
}


@end
