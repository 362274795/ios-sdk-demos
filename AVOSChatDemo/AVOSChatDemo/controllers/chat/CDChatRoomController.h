//
//  CDChatRoomController.h
//  AVOSChatDemo
//
//  Created by Qihe Bian on 7/28/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import "CDBaseController.h"
#import "CDCommon.h"
#import "JSQMessages.h"
#import "CDSessionManager.h"

@interface CDChatRoomController : JSQMessagesViewController

@property (nonatomic, strong) User *chatUser;
@property (nonatomic) CDMsgRoomType type;
@property (nonatomic, strong) AVGroup *group;

@property (strong, nonatomic) JSQMessagesBubbleImage *outgoingBubbleImageData;
@property (strong, nonatomic) JSQMessagesBubbleImage *incomingBubbleImageData;

@property (nonatomic, strong) NSMutableArray *messages;

@end
