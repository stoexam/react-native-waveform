//
//  WaveformDialog.h
//  WaveformViewModule
//
//  Created by admin on 2017/6/27.
//  Copyright © 2017年 Erdem Başeğmez. All rights reserved.
//

#import <UIKit/UIKit.h>

#define SCREEN_WIDTH ([UIScreen mainScreen].bounds.size.width)
#define SCREEN_HEIGHT ([UIScreen mainScreen].bounds.size.height)


typedef void(^backBolock)(NSDictionary * );

@interface WaveformDialog : UIView<UIPickerViewDataSource,UIPickerViewDelegate>

@property (strong,nonatomic)UIPickerView *pick;

@property(nonatomic,copy)backBolock bolock;

//创建一个数组来传递返回的值
//@property(nonatomic,strong)NSMutableArray *backArry;
@property(nonatomic,strong)NSString *backString;

-(instancetype)initWithFrame:(CGRect)frame
                         /*dic:(NSDictionary *)dic
                     leftStr:(NSString *)leftStr
                   centerStr:(NSString *)centerStr
                    rightStr:(NSString *)rightStr
                  topbgColor:(NSArray *)topbgColor
               bottombgColor:(NSArray *)bottombgColor
              leftbtnbgColor:(NSArray *)leftbtnbgColor
             rightbtnbgColor:(NSArray *)rightbtnbgColor
              centerbtnColor:(NSArray *)centerbtnColor
             selectValueArry:(NSArray *)selectValueArry
                  weightArry:(NSArray *)weightArry
       pickerToolBarFontSize:(NSString *)pickerToolBarFontSize
              pickerFontSize:(NSString *)pickerFontSize
             pickerFontColor:(NSArray *)pickerFontColor*/
;

//-(void)selectRow;
@end
