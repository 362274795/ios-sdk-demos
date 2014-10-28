//
//  Utils.h
//  AVOSChatDemo
//
//  Created by lzw on 14-10-24.
//  Copyright (c) 2014年 AVOS. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Utils : NSObject
+(void)alert:(NSString*)msg;
+(NSString*)md5:(NSString*)s;
+(void)alertError:(NSError*)error;
@end
