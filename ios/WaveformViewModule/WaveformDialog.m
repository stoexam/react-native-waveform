//
//  WaveformDialog.m
//  WaveformViewModule
//
//  Created by admin on 2017/6/27.
//  Copyright © 2017年 Erdem Başeğmez. All rights reserved.
//

#import "WaveformDialog.h"
#define linSpace 5

@implementation WaveformDialog

-(instancetype)initWithFrame:(CGRect)frame /*dic:(NSDictionary *)dic leftStr:(NSString *)leftStr centerStr:(NSString *)centerStr rightStr:(NSString *)rightStr topbgColor:(NSArray *)topbgColor bottombgColor:(NSArray *)bottombgColor leftbtnbgColor:(NSArray *)leftbtnbgColor rightbtnbgColor:(NSArray *)rightbtnbgColor centerbtnColor:(NSArray *)centerbtnColor selectValueArry:(NSArray *)selectValueArry  weightArry:(NSArray *)weightArry
pickerToolBarFontSize:(NSString *)pickerToolBarFontSize  pickerFontSize:(NSString *)pickerFontSize  pickerFontColor:(NSArray *)pickerFontColor*/

{
    self = [super initWithFrame:frame];
    if (self)
    {
        /*self.backArry=[[NSMutableArray alloc]init];
        self.provinceArray=[[NSMutableArray alloc]init];
        self.cityArray=[[NSMutableArray alloc]init];
        self.selectValueArry=selectValueArry;
        self.weightArry=weightArry;
        self.pickerDic=dic;
        self.leftStr=leftStr;
        self.rightStr=rightStr;
        self.centStr=centerStr;
        self.pickerToolBarFontSize=pickerToolBarFontSize;
        self.pickerFontSize=pickerFontSize;
        self.pickerFontColor=pickerFontColor;
        [self getStyle];
        [self getnumStyle];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self makeuiWith:topbgColor With:bottombgColor With:leftbtnbgColor With:rightbtnbgColor With:centerbtnColor];
            [self selectRow];
        });*/
    }
    return self;
}

//按了确定按钮
-(void)cfirmAction
{
    NSMutableDictionary *dic=[[NSMutableDictionary alloc]init];
    
    if (self.backString != nil && self.backString != NULL) {
        
        //[dic setValue:self.backArry forKey:@"selectedValue"];
        [dic setValue:@"confirm" forKey:@"type"];
        NSMutableArray *arry=[[NSMutableArray alloc]init];
        //[dic setValue:[self getselectIndexArry] forKey:@"selectedIndex"];
        //[dic setValue:arry forKey:@"selectedIndex"];
        //[dic setValue:self.backArry forKey:@"voiceResult"];
        [dic setValue:self.backString forKey:@"voiceResult"];
        
        self.bolock(dic);
        
    }else{
        [self getNOselectinfo];
        //[dic setValue:self.backArry forKey:@"voiceResult"];
        [dic setValue:self.backString forKey:@"voiceResult"];
        [dic setValue:@"confirm" forKey:@"type"];
        
        //[dic setValue:[self getselectIndexArry] forKey:@"selectedIndex"];
        
        self.bolock(dic);
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:.2f animations:^{
            
            [self setFrame:CGRectMake(0, SCREEN_HEIGHT, SCREEN_WIDTH, 250)];
        }];
    });
    
}

-(void)getNOselectinfo
{
    //[self.backArry addObject:[self.noCorreArry objectAtIndex:0]];
    
    self.backString = @"";
}


@end
