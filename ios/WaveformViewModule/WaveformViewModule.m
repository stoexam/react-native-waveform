//
//  WaveformViewModule.m
//  WaveformViewModule
//
//  Created by lixl on 24.06.2017.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import "WaveformViewModule.h"
//#import <React/RCTConvert.h>
//#import <React/RCTBridge.h>
//#import "FlySpeechUtility.h"
//#import "RCTEventDispatcher.h"
#import <React/RCTEventDispatcher.h>

#import "ISEParams.h"
#import "PopupView.h"
#import "iflyMSC/IFlyMSC.h"

#import <objc/runtime.h>

#import "ISEResult.h"
#import "ISEResultXmlParser.h"
#import "Definition.h"

#import "WaveformDialog.h"

#pragma mark - const values

NSString* const KCIseHideBtnTitle=@"隐藏";

NSString* const KCTextCNSyllable=@"text_cn_syllable";
NSString* const KCTextCNWord=@"text_cn_word";
NSString* const KCTextCNSentence=@"text_cn_sentence";
NSString* const KCTextENWord=@"text_en_word";
NSString* const KCTextENSentence=@"text_en_sentence";

NSString* const KCResultNotify1=@"请点击“开始评测”按钮";
NSString* const KCResultNotify2=@"请朗读以上内容";
NSString* const KCResultNotify3=@"停止评测，结果等待中...";


#pragma mark -

@interface WaveformViewModule () <IFlySpeechEvaluatorDelegate, ISESettingDelegate, ISEResultXmlParserDelegate ,IFlyPcmRecorderDelegate
>

@property(nonatomic,strong)WaveformDialog *pick;
@property(nonatomic,assign)float height;
@property(nonatomic,weak)UIWindow * window;

@property (nonatomic, strong) NSString* resultText;

@property (nonatomic, strong) PopupView *popupView;
@property (nonatomic, strong) IFlySpeechEvaluator *iFlySpeechEvaluator;

@property (nonatomic, assign) BOOL isSessionResultAppear;
@property (nonatomic, assign) BOOL isSessionEnd;

@property (nonatomic, assign) BOOL isValidInput;
@property (nonatomic, assign) BOOL isDidset;

@property (nonatomic,strong) IFlyPcmRecorder *pcmRecorder;//录音器，用于音频流识别的数据传入
@property (nonatomic,assign) BOOL isBeginOfSpeech;//是否已经返回BeginOfSpeech回调

@end


@implementation WaveformViewModule

@synthesize bridge = _bridge;

//NSString *resultView = nil;
//NSString *resultText = nil;

NSString *selfVoice = nil;

RCT_EXPORT_MODULE();

//测试用  弹出 对话框
RCT_EXPORT_METHOD(alert:(NSString *)message){
        //alert
    
    NSString *title = NSLocalizedString(@"", nil);
    NSString *message2 = NSLocalizedString(message, nil);
    NSString *cancelButtonTitle = NSLocalizedString(@"Cancel", nil);
    NSString *otherButtonTitle = NSLocalizedString(@"OK", nil);
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:message2 preferredStyle:UIAlertControllerStyleAlert];
    
    // Create the actions.
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:cancelButtonTitle style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        NSLog(@"The \"Okay/Cancel\" alert's cancel action occured.");
    }];
    
    UIAlertAction *otherAction = [UIAlertAction actionWithTitle:otherButtonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSLog(@"The \"Okay/Cancel\" alert's other action occured.");
    }];
    
    // Add the actions.
    [alertController addAction:cancelAction];
    [alertController addAction:otherAction];
    
    //[self presentViewController:alertController animated:YES completion:nil];
    [self.class presentViewController:alertController animated:YES completion:nil];
}

-(void)initIFly: (NSString *)standardTxt {
    NSLog(@"%s[IN]",__func__);
    
    [self.iFlySpeechEvaluator setParameter:@"16000" forKey:[IFlySpeechConstant SAMPLE_RATE]];
    [self.iFlySpeechEvaluator setParameter:@"utf-8" forKey:[IFlySpeechConstant TEXT_ENCODING]];
    [self.iFlySpeechEvaluator setParameter:@"xml" forKey:[IFlySpeechConstant ISE_RESULT_TYPE]];
    //[self.iFlySpeechEvaluator setParameter:@"json" forKey:[IFlySpeechConstant ISE_RESULT_TYPE]];
    
    //[self.iFlySpeechEvaluator setParameter:@"eva.pcm" forKey:[IFlySpeechConstant ISE_AUDIO_PATH]];
    [self.iFlySpeechEvaluator setParameter:@"self.mp3" forKey:[IFlySpeechConstant ISE_AUDIO_PATH]];
    
    NSStringEncoding encoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
    
    NSLog(@"text encoding:%@",[self.iFlySpeechEvaluator parameterForKey:[IFlySpeechConstant TEXT_ENCODING]]);
    NSLog(@"language:%@",[self.iFlySpeechEvaluator parameterForKey:[IFlySpeechConstant LANGUAGE]]);
    
    BOOL isUTF8=[[self.iFlySpeechEvaluator parameterForKey:[IFlySpeechConstant TEXT_ENCODING]] isEqualToString:@"utf-8"];
    BOOL isZhCN=[[self.iFlySpeechEvaluator parameterForKey:[IFlySpeechConstant LANGUAGE]] isEqualToString:KCLanguageZHCN];
    
    BOOL needAddTextBom=isUTF8&&isZhCN;
    NSMutableData *buffer = nil;
    
    if(needAddTextBom){
        //if(self.textView.text && [self.textView.text length]>0)
        if(standardTxt && [standardTxt length]>0)
        {
            Byte bomHeader[] = { 0xEF, 0xBB, 0xBF };
            buffer = [NSMutableData dataWithBytes:bomHeader length:sizeof(bomHeader)];
            [buffer appendData:[standardTxt dataUsingEncoding:NSUTF8StringEncoding]];
            NSLog(@" \ncn buffer length: %lu",(unsigned long)[buffer length]);
        }
    }else{
        buffer= [NSMutableData dataWithData:[standardTxt dataUsingEncoding:encoding]];
        NSLog(@" \nen buffer length: %lu",(unsigned long)[buffer length]);
    }
    //self.resultView.text =KCResultNotify2;
    //self.resultText=@"";
    
    BOOL ret = [self.iFlySpeechEvaluator startListening:buffer params:nil];
    if(ret){
        self.isSessionResultAppear=NO;
        self.isSessionEnd=NO;
        //self.startBtn.enabled=NO;
        
        //采用音频流评测，将评测音频数据通过writeAudio:传入。使用方法类似于语音听写控件中的音频流识别功能。
        if ([self.iseParams.audioSource isEqualToString:IFLY_AUDIO_SOURCE_STREAM]){
            
            _isBeginOfSpeech = NO;
            //初始化录音环境
            [IFlyAudioSession initRecordingAudioSession];
            
            _pcmRecorder.delegate = self;
            
            //启动录音器服务
            BOOL ret = [_pcmRecorder start];
            
            NSLog(@"%s[OUT],Success,Recorder ret=%d",__func__,ret);
        }
    }
    
    
}

//NSString *standardTxt = nil;

//初始化：  1 波形    2  对话框   3   语音识别
RCT_EXPORT_METHOD(_init:
                  (NSDictionary *)options){
    //NSMutableDictionary *output = [[NSMutableDictionary alloc] init];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication].keyWindow endEditing:YES];
    });

    [self.window.subviews enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if ([obj isKindOfClass:[WaveformDialog class]]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [obj removeFromSuperview];
            });
        }
        
    }];
    
    if ([[UIDevice currentDevice].systemVersion doubleValue] >= 9.0 ) {
        self.height=250;
    }else{
        self.height=220;
    }
    
    self.pick=[[WaveformDialog alloc]initWithFrame:CGRectMake(0, SCREEN_HEIGHT, SCREEN_WIDTH, self.height) /*dic:dataDic leftStr:pickerCancelBtnText centerStr:pickerTitleText rightStr:pickerConfirmBtnText topbgColor:pickerToolBarBg bottombgColor:pickerBg leftbtnbgColor:pickerCancelBtnColor rightbtnbgColor:pickerConfirmBtnColor centerbtnColor:pickerTitleColor selectValueArry:selectArry weightArry:weightArry pickerToolBarFontSize:pickerToolBarFontSize pickerFontSize:pickerFontSize pickerFontColor:pickerFontColor*/
               ];
    
    
    _pick.bolock=^(NSDictionary *backinfoArry)
    {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [self.bridge.eventDispatcher sendAppEventWithName:@"confirmEvent" body:backinfoArry];
        });
    };
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [self.window addSubview:_pick];
        
        [UIView animateWithDuration:.3 animations:^{
            
            [_pick setFrame:CGRectMake(0, SCREEN_HEIGHT-self.height, SCREEN_WIDTH, self.height)];
            
        }];
        
    });
    
    NSString *standardTxt = @"";
    if ([options count] != 0) {
        standardTxt = options[@"standardTxt"];
        
        id pickerData = options[@"confirmEvent"];
        
        self.selfVoiceDir = options[@"destinationDir"];
    }
    
    //[output setValue:@"" forKey:@"content"];
    
    //1
    
    //2
    
    //3
    if (!self.iFlySpeechEvaluator) {
        self.iFlySpeechEvaluator = [IFlySpeechEvaluator sharedInstance];
    }
    self.iFlySpeechEvaluator.delegate = self;
    //清空参数，目的是评测和听写的参数采用相同数据
    [self.iFlySpeechEvaluator setParameter:@"" forKey:[IFlySpeechConstant PARAMS]];
    _isSessionResultAppear=YES;
    _isSessionEnd=YES;
    _isValidInput=YES;
    self.iseParams=[ISEParams fromUserDefaults];
    [self reloadCategoryText];
    
    //初始化录音器
    if (_pcmRecorder == nil)
    {
        _pcmRecorder = [IFlyPcmRecorder sharedInstance];
    }
    
    _pcmRecorder.delegate = self;
    
    [_pcmRecorder setSample:@"16000"];
    
    [_pcmRecorder setSaveAudioPath:nil];    //不保存录音文件
    //NSString *fileName = [self get_filename:[self.selfVoiceDir stringByAppendingString:@"self"]];
    //[_pcmRecorder setSaveAudioPath:fileName];
    
    //避免同时产生多个按钮事件
//    [self setExclusiveTouchForButtons:self.view];
    
    
    //Appid 是应用的身份信息，具有唯一性，初始化时必须要传入 Appid。
    NSString *initString = [[NSString alloc] initWithFormat:@"appid=%@", @"594e1124"];
    [IFlySpeechUtility createUtility:initString];
    [self initIFly: standardTxt];
    
    //callback(@[output]);
}

RCT_EXPORT_METHOD(start:
                  (NSDictionary *)options) {
    
    NSString *standardTxt = @"";
    if ([options count] != 0) {
        standardTxt = options[@"standardTxt"];
    }
    [self initIFly: standardTxt];

}

RCT_EXPORT_METHOD(stop) {
    
    if(!self.isSessionResultAppear &&  !self.isSessionEnd){
        //self.resultView.text =KCResultNotify3;
        self.resultText=@"";
    }
    
    if ([self.iseParams.audioSource isEqualToString:IFLY_AUDIO_SOURCE_STREAM] && !_isBeginOfSpeech){
        NSLog(@"%s,停止录音",__func__);
        [_pcmRecorder stop];
    }
    
    [self.iFlySpeechEvaluator stopListening];
    
    //[self.resultView resignFirstResponder];
    //[self.textView resignFirstResponder];
    //self.startBtn.enabled=YES;
    
    /*showTip("mIse.isEvaluating()=" + (mIse.isEvaluating()));
    if (mIse.isEvaluating()) {
        mIse.stopEvaluating();
        showTip("mIse.isEvaluating()=" + (mIse.isEvaluating()));
     }*/
    [self hideDialog];
    
}


RCT_EXPORT_METHOD(isWaveformShow:
                  (RCTResponseSenderBlock)callback) {
    
    /*
    if (callback == null)
        return;
    if (dialog == null) {
        callback.invoke(ERROR_NOT_INIT);
    } else {
        callback.invoke(null, dialog.isShowing());
    }
    */
    if (self.pick) {
        
        CGFloat pickY=_pick.frame.origin.y;
        
        if (pickY==SCREEN_HEIGHT) {
            
            callback(@[@YES]);
        }else
        {
            callback(@[@NO]);
        }
    }else{
        callback(@[@"picker不存在"]);
    }
    
}

- (void)hideDialog{
    /*if (dialog == null) {
        return;
    }
    if (dialog.isShowing()) {
        
        isAlive = false;
        mMediaRecorder.stop();
        mMediaRecorder.release();
        mMediaRecorder = null;
        
        dialog.dismiss();
        handler.removeCallbacks(this);
        
    }*/
    if (self.pick) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:.3 animations:^{
                [_pick setFrame:CGRectMake(0, SCREEN_HEIGHT, SCREEN_WIDTH, self.height)];
            }];
        });
    }return;
}

//根据文件名，读取
-(NSString *)get_filename:(NSString *)name
{
    NSString *result = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]
                        stringByAppendingPathComponent:name];
    NSLog(@"get_filename: %@", result);
    return result;
}

#pragma mark - IFlySpeechEvaluatorDelegate
/*!
 *  音量和数据回调
 *
 *  @param volume 音量
 *  @param buffer 音频数据
 */
- (void)onVolumeChanged:(int)volume buffer:(NSData *)buffer {
    //    NSLog(@"volume:%d",volume);
    [self.popupView setText:[NSString stringWithFormat:@"音量：%d",volume]];
    //[self.view addSubview:self.popupView];
}

/*!
 *  开始录音回调
 *  当调用了`startListening`函数之后，如果没有发生错误则会回调此函数。如果发生错误则回调onError:函数
 */
- (void)onBeginOfSpeech {
    
    if ([self.iseParams.audioSource isEqualToString:IFLY_AUDIO_SOURCE_STREAM]){
        _isBeginOfSpeech =YES;
    }
    
}

/*!
 *  停止录音回调
 *    当调用了`stopListening`函数或者引擎内部自动检测到断点，如果没有发生错误则回调此函数。
 *  如果发生错误则回调onError:函数
 */
- (void)onEndOfSpeech {
    
    if ([self.iseParams.audioSource isEqualToString:IFLY_AUDIO_SOURCE_STREAM]){
        [_pcmRecorder stop];
    }
    
}

/*!
 *  正在取消
 */
- (void)onCancel {
    
}

/*!
 *  评测结果回调
 *    在进行语音评测过程中的任何时刻都有可能回调此函数，你可以根据errorCode进行相应的处理.
 *  当errorCode没有错误时，表示此次会话正常结束，否则，表示此次会话有错误发生。特别的当调用
 *  `cancel`函数时，引擎不会自动结束，需要等到回调此函数，才表示此次会话结束。在没有回调此函
 *  数之前如果重新调用了`startListenging`函数则会报错误。
 *
 *  @param errorCode 错误描述类
 */
- (void)onError:(IFlySpeechError *)errorCode {
    if(errorCode && errorCode.errorCode!=0){
        [self.popupView setText:[NSString stringWithFormat:@"错误码：%d %@",[errorCode errorCode],[errorCode errorDesc]]];
        //[self.view addSubview:self.popupView];
        
        NSLog(@"[错误码:%d][错误:%@]",[errorCode errorCode], [errorCode errorDesc]);
    }
    
    //[self performSelectorOnMainThread:@selector(resetBtnSatus:) withObject:errorCode waitUntilDone:NO];
    
}

/*!
 *  评测结果回调
 *   在评测过程中可能会多次回调此函数，你最好不要在此回调函数中进行界面的更改等操作，只需要将回调的结果保存起来。
 *
 *  @param results -[out] 评测结果。
 *  @param isLast  -[out] 是否最后一条结果
 */
- (void)onResults:(NSData *)results isLast:(BOOL)isLast{
    if (results) {
        NSString *showText = @"";
        
        const char* chResult=[results bytes];
        
        BOOL isUTF8=[[self.iFlySpeechEvaluator parameterForKey:[IFlySpeechConstant RESULT_ENCODING]]isEqualToString:@"utf-8"];
        NSString* strResults=nil;
        if(isUTF8){
            strResults=[[NSString alloc] initWithBytes:chResult length:[results length] encoding:NSUTF8StringEncoding];
        }else{
            NSLog(@"result encoding: gb2312");
            NSStringEncoding encoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
            strResults=[[NSString alloc] initWithBytes:chResult length:[results length] encoding:encoding];
        }
        if(strResults){
            showText = [showText stringByAppendingString:strResults];
        }
        
        self.resultText=showText;
        //self.resultView.text = showText;
        self.isSessionResultAppear=YES;
        self.isSessionEnd=YES;
        if(isLast){
            [self.popupView setText:@"评测结束"];
            //[self.view addSubview:self.popupView];
        }
        
        
        [self commonEvent];
        
        
    }
    else{
        if(isLast){
            [self.popupView setText:@"你好像没有说话哦"];
            //[self.view addSubview:self.popupView];
        }
        self.isSessionEnd=YES;
    }
    //self.startBtn.enabled=YES;
}

- (void)commonEvent {
    /*
    WritableMap map = Arguments.createMap();
    map.putString("type", eventKey);
    
    String voiceResult = "";
    // 解析最终结果
    if (!TextUtils.isEmpty(mLastResult)) {
        com.iflytek.ise.result.xml.XmlResultParser resultParser = new com.iflytek.ise.result.xml.XmlResultParser();
        com.iflytek.ise.result.Result result = resultParser.parse(mLastResult);
        
        if (null != result) {
            voiceResult = result.toString();
            Log.d(TAG, "结果：" + voiceResult);
            showTip("结果：" + voiceResult);
        } else {
            showTip("解析结果为空");
        }
    }
    
    map.putString("voiceResult", voiceResult);
    sendEvent(getReactApplicationContext(), CONFIRM_EVENT_NAME, map);
     */
    
    NSLog(@"===================resultText xml====================");
    NSLog(@"%@", self.resultText);
    
    ISEResultXmlParser* parser=[[ISEResultXmlParser alloc] init];
    parser.delegate=self;
    [parser parserXml:self.resultText];
    
}

#pragma mark - ISEResultXmlParserDelegate


-(void)onISEResultXmlParser:(NSXMLParser *)parser Error:(NSError*)error{
    
}

-(void)onISEResultXmlParserResult:(ISEResult*)result{
    //self.resultView.text=[result toString];
    //NSLog(@"===================xml====================");
    //NSLog(@"%@", [result toString]);
    
    NSString *resultJson = nil;
    NSDictionary *dict = [WaveformViewModule getObjectData:result];
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
    if ([jsonData length] > 0 && error == nil){
        resultJson = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    NSLog(@"===================json====================");
    NSLog(@"%@", resultJson);
    
    NSMutableDictionary *dic=[[NSMutableDictionary alloc]init];
    [dic setValue:@"confirm" forKey:@"type"];
    [dic setValue:resultJson forKey:@"voiceResult"];
    _pick.bolock(dic);
}

#pragma mark - IFlyPcmRecorderDelegate

- (void) onIFlyRecorderBuffer: (const void *)buffer bufferSize:(int)size
{
    NSData *audioBuffer = [NSData dataWithBytes:buffer length:size];
    
    int ret = [self.iFlySpeechEvaluator writeAudio:audioBuffer];
    if (!ret)
    {
        [self.iFlySpeechEvaluator stopListening];
    }
}

- (void) onIFlyRecorderError:(IFlyPcmRecorder*)recoder theError:(int) error
{
    if(error){
    }
    NSLog(@"onIFlyRecorderError: %d", error);
}


/*static NSString *LocalizedEvaString(NSString *key, NSString *comment) {
    return NSLocalizedStringFromTable(key, @"eva/eva", comment);
}
#pragma mark -

- (void)viewWillAppear:(BOOL)animated {
    
    // register for keyboard notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    
    [super viewWillAppear:animated];
    self.iFlySpeechEvaluator.delegate = self;
    
    self.isSessionResultAppear=YES;
    self.isSessionEnd=YES;
    //self.startBtn.enabled=YES;
}

- (void)viewWillDisappear:(BOOL)animated{
    
    //     unregister for keyboard notifications while not visible.
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillShowNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillHideNotification
                                                  object:nil];
    [self.iFlySpeechEvaluator cancel];
    self.iFlySpeechEvaluator.delegate = nil;
    //self.resultView.text =KCResultNotify1;
    self.resultText=@"";
    
    [_pcmRecorder stop];
    _pcmRecorder.delegate = nil;
    
    [super viewWillDisappear:animated];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // adjust the UI for iOS 7
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    if (IOS7_OR_LATER) {
//        self.edgesForExtendedLayout = UIRectEdgeNone;
//        self.extendedLayoutIncludesOpaqueBars = NO;
//        self.modalPresentationCapturesStatusBarAppearance = NO;
//        self.navigationController.navigationBar.translucent = NO;
    }
#endif
    
    //键盘工具栏
    UIBarButtonItem *spaceBtnItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                                  target:nil
                                                                                  action:nil];
    UIBarButtonItem *hideBtnItem = [[UIBarButtonItem alloc] initWithTitle:KCIseHideBtnTitle
                                                                    style:UIBarButtonItemStylePlain
                                                                   target:self
                                                                   action:@selector(onKeyBoardDown:)];
    [hideBtnItem setTintColor:[UIColor whiteColor]];
 
    UIToolbar *keyboardToolbar = [[UIToolbar alloc]initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, _DEMO_UI_TOOLBAR_HEIGHT)];
    keyboardToolbar.barStyle = UIBarStyleBlackTranslucent;
    NSArray *array = [NSArray arrayWithObjects:spaceBtnItem, hideBtnItem, nil];
    [keyboardToolbar setItems:array];
    self.textView.inputAccessoryView = keyboardToolbar;
    
    self.textView.layer.cornerRadius = 8;
    self.textView.layer.borderWidth = 1;
    self.textView.layer.borderColor =[[UIColor whiteColor] CGColor];
    
    self.resultView.layer.cornerRadius = 8;
    self.resultView.layer.borderWidth = 1;
    self.resultView.layer.borderColor =[[UIColor whiteColor] CGColor];
    [self.resultView setEditable:NO];
 
    self.popupView = [[PopupView alloc]initWithFrame:CGRectMake(100, 300, 0, 0)];
    //self.popupView.ParentView = self.view;
    
    
    if (!self.iFlySpeechEvaluator) {
        self.iFlySpeechEvaluator = [IFlySpeechEvaluator sharedInstance];
    }
    self.iFlySpeechEvaluator.delegate = self;
    //清空参数，目的是评测和听写的参数采用相同数据
    [self.iFlySpeechEvaluator setParameter:@"" forKey:[IFlySpeechConstant PARAMS]];
    _isSessionResultAppear=YES;
    _isSessionEnd=YES;
    _isValidInput=YES;
    self.iseParams=[ISEParams fromUserDefaults];
    //[self reloadCategoryText];
    
    //初始化录音器
    if (_pcmRecorder == nil)
    {
        _pcmRecorder = [IFlyPcmRecorder sharedInstance];
    }
    
    _pcmRecorder.delegate = self;
    
    [_pcmRecorder setSample:@"16000"];
    
    [_pcmRecorder setSaveAudioPath:nil];    //不保存录音文件
    
    //避免同时产生多个按钮事件
    //[self setExclusiveTouchForButtons:self.view];
}
 */

//设置ifly的参数
-(void)reloadCategoryText{
    
    [self.iFlySpeechEvaluator setParameter:self.iseParams.bos forKey:[IFlySpeechConstant VAD_BOS]];
    [self.iFlySpeechEvaluator setParameter:self.iseParams.eos forKey:[IFlySpeechConstant VAD_EOS]];
    [self.iFlySpeechEvaluator setParameter:self.iseParams.category forKey:[IFlySpeechConstant ISE_CATEGORY]];
    [self.iFlySpeechEvaluator setParameter:self.iseParams.language forKey:[IFlySpeechConstant LANGUAGE]];
    [self.iFlySpeechEvaluator setParameter:self.iseParams.rstLevel forKey:[IFlySpeechConstant ISE_RESULT_LEVEL]];
    [self.iFlySpeechEvaluator setParameter:self.iseParams.timeout forKey:[IFlySpeechConstant SPEECH_TIMEOUT]];
    [self.iFlySpeechEvaluator setParameter:self.iseParams.audioSource forKey:[IFlySpeechConstant AUDIO_SOURCE]];
    
    if ([self.iseParams.language isEqualToString:KCLanguageZHCN]) {
        if ([self.iseParams.category isEqualToString:KCCategorySyllable]) {
            //self.textView.text = LocalizedEvaString(KCTextCNSyllable, nil);
        }
        else if ([self.iseParams.category isEqualToString:KCCategoryWord]) {
            //self.textView.text = LocalizedEvaString(KCTextCNWord, nil);
        }
        else {
            //self.textView.text = LocalizedEvaString(KCTextCNSentence, nil);
        }
    }
    else {
        if ([self.iseParams.category isEqualToString:KCCategoryWord]) {
            //self.textView.text = LocalizedEvaString(KCTextENWord, nil);
        }
        else {
            //self.textView.text = LocalizedEvaString(KCTextENSentence, nil);
        }
        self.isValidInput=YES;
        
    }
}

#pragma mark - keyboard

+ (NSDictionary*)getObjectData:(id)obj
{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    unsigned int propsCount;
    
    //id classObject = objc_getClass([@"ISEResult" UTF8String]);
    NSString* objClassName = NSStringFromClass([obj class]);
    id classObject = objc_getClass([objClassName UTF8String]);
    
    //objc_property_t *props = class_copyPropertyList([obj class], &propsCount);//获得属性列表 由 @property 修饰的变量
    objc_property_t *props = class_copyPropertyList(classObject, &propsCount);
    //Ivar *props = class_copyIvarList([obj class], &propsCount);
    for(int i = 0;i < propsCount; i++)
    {
        objc_property_t prop = props[i];
        
        NSString *propName = [NSString stringWithUTF8String:property_getName(prop)];//获得属性的名称
        id value = [obj valueForKey:propName];//kvc读值
        if(value == nil)
        {
            value = [NSNull null];
        }
        else
        {
            value = [self getObjectInternal:value];//自定义处理数组，字典，其他类
        }
        [dic setObject:value forKey:propName];
    }
    free(props);
    return dic;
}

+ (id)getObjectInternal:(id)obj
{
    if([obj isKindOfClass:[NSString class]]
       || [obj isKindOfClass:[NSNumber class]]
       || [obj isKindOfClass:[NSNull class]])
    {
        return obj;
    }
    
    if([obj isKindOfClass:[NSArray class]])
    {
        NSArray *objarr = obj;
        NSMutableArray *arr = [NSMutableArray arrayWithCapacity:objarr.count];
        for(int i = 0;i < objarr.count; i++)
        {
            [arr setObject:[self getObjectInternal:[objarr objectAtIndex:i]] atIndexedSubscript:i];
        }
        return arr;
    }
    
    if([obj isKindOfClass:[NSDictionary class]])
    {
        NSDictionary *objdic = obj;
        NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithCapacity:[objdic count]];
        for(NSString *key in objdic.allKeys)
        {
            [dic setObject:[self getObjectInternal:[objdic objectForKey:key]] forKey:key];
        }
        return dic;
    }
    return [self getObjectData:obj];
}

@end