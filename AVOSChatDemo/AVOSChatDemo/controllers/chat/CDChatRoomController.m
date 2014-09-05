//
//  CDChatRoomController.m
//  AVOSChatDemo
//
//  Created by Qihe Bian on 7/28/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import "CDChatRoomController.h"
#import "CDSessionManager.h"
#import "CDChatDetailController.h"

@interface CDChatRoomController () <JSMessagesViewDelegate, JSMessagesViewDataSource> {
    NSMutableArray *_timestampArray;
    NSDate *_lastTime;
}
@property (nonatomic, strong) NSArray *messages;
@end

@implementation CDChatRoomController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)init {
    if ((self = [super init])) {
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    if (self.type == CDChatRoomTypeGroup) {
        NSString *title = @"group";
        if (self.group.groupId) {
            title = [NSString stringWithFormat:@"group:%@", self.group.groupId];
        }
        self.title = title;
    } else {
        self.title = self.otherId;
    }
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(showDetail:)];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdated:) name:NOTIFICATION_MESSAGE_UPDATED object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionUpdated:) name:NOTIFICATION_SESSION_UPDATED object:nil];
    
    self.delegate = self;
    self.dataSource = self;

//    if (self.group.groupId) {
//    AVObject *groupObject = [AVObject objectWithoutDataWithClassName:@"AVOSRealtimeGroups" objectId:self.group.groupId];
//    [groupObject fetch];
//    NSArray *groupMembers = [groupObject objectForKey:@"m"];
//        
//        [self.group invite:@[@"peerId1",@"peerId2",@"peerId3"]];
//        [self.group kick:@[@"peerId1",@"peerId2",@"peerId3"]];
//    }
//    self.messageArray = [NSMutableArray array];
//    self.timestamps = [NSMutableArray array];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self messageUpdated:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)refreshTimestampArray {
    NSDate *lastDate = nil;
    NSMutableArray *hasTimestampArray = [NSMutableArray array];
    for (NSDictionary *dict in self.messages) {
        NSDate *date = [dict objectForKey:@"time"];
        if (!lastDate) {
            lastDate = date;
            [hasTimestampArray addObject:[NSNumber numberWithBool:YES]];
        } else {
            if ([date timeIntervalSinceDate:lastDate] > 60) {
                [hasTimestampArray addObject:[NSNumber numberWithBool:YES]];
                lastDate = date;
            } else {
                [hasTimestampArray addObject:[NSNumber numberWithBool:NO]];
            }
        }
    }
    _timestampArray = hasTimestampArray;
}

- (void)showDetail:(id)sender {
    CDChatDetailController *controller = [[CDChatDetailController alloc] init];
    controller.type = self.type;
    if (self.type == CDChatRoomTypeSingle) {
        controller.otherId = self.otherId;
    } else if (self.type == CDChatRoomTypeGroup) {
        controller.otherId = self.group.groupId;
    }
    [self.navigationController pushViewController:controller animated:YES];
}

#pragma mark - Table view data source
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.messages.count;
}

#pragma mark - Messages view delegate
- (void)sendPressed:(UIButton *)sender withText:(NSString *)text {
//    [self.messageArray addObject:[NSDictionary dictionaryWithObject:text forKey:@"Text"]];
//    
//    [self.timestamps addObject:[NSDate date]];
//    
//    if((self.messageArray.count - 1) % 2)
//        [JSMessageSoundEffect playMessageSentSound];
//    else
//        [JSMessageSoundEffect playMessageReceivedSound];
//    NSString *message = [[textView.text stringByReplacingCharactersInRange:range withString:text] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
//    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
//    [dict setObject:self.session.getSelfPeerId forKey:@"dn"];
//    [dict setObject:text forKey:@"msg"];
//    NSError *error = nil;
//    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
//    NSString *message = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
//    [self.session sendMessage:message isTransient:NO toPeerIds:self.session.getAllPeers];
//    [_messages addObject:[[KAMessage alloc] initWithDisplayName:MY_NAME Message:message fromMe:YES]];
    if (self.type == CDChatRoomTypeGroup) {
        if (!self.group.groupId) {
            return;
        }
        [[CDSessionManager sharedInstance] sendMessage:text toGroup:self.group.groupId];
    } else {
        [[CDSessionManager sharedInstance] sendMessage:text toPeerId:self.otherId];
    }
    [self refreshTimestampArray];
    [self finishSend];
}

- (void)cameraPressed:(id)sender{
    
//    [self.inputToolBarView.textView resignFirstResponder];
//    
//    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:nil otherButtonTitles:@"拍照",@"相册", nil];
//    [actionSheet showInView:self.view];
}

- (JSBubbleMessageType)messageTypeForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *fromid = [[self.messages objectAtIndex:indexPath.row] objectForKey:@"fromid"];
    
    return (![fromid isEqualToString:[AVUser currentUser].username]) ? JSBubbleMessageTypeIncoming : JSBubbleMessageTypeOutgoing;
}

- (JSBubbleMessageStyle)messageStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return JSBubbleMessageStyleFlat;
}

- (JSBubbleMediaType)messageMediaTypeForRowAtIndexPath:(NSIndexPath *)indexPath {
    return JSBubbleMediaTypeText;
//    if([[self.messageArray objectAtIndex:indexPath.row] objectForKey:@"Text"]){
//        return JSBubbleMediaTypeText;
//    }else if ([[self.messageArray objectAtIndex:indexPath.row] objectForKey:@"Image"]){
//        return JSBubbleMediaTypeImage;
//    }
//    
//    return -1;
}

- (UIButton *)sendButton
{
    return [UIButton defaultSendButton];
}

- (JSMessagesViewTimestampPolicy)timestampPolicy
{
    /*
     JSMessagesViewTimestampPolicyAll = 0,
     JSMessagesViewTimestampPolicyAlternating,
     JSMessagesViewTimestampPolicyEveryThree,
     JSMessagesViewTimestampPolicyEveryFive,
     JSMessagesViewTimestampPolicyCustom
     */
    return JSMessagesViewTimestampPolicyCustom;
}

- (JSMessagesViewAvatarPolicy)avatarPolicy
{
    /*
     JSMessagesViewAvatarPolicyIncomingOnly = 0,
     JSMessagesViewAvatarPolicyBoth,
     JSMessagesViewAvatarPolicyNone
     */
    return JSMessagesViewAvatarPolicyNone;
}

- (JSAvatarStyle)avatarStyle
{
    /*
     JSAvatarStyleCircle = 0,
     JSAvatarStyleSquare,
     JSAvatarStyleNone
     */
    return JSAvatarStyleNone;
}

- (JSInputBarStyle)inputBarStyle
{
    /*
     JSInputBarStyleDefault,
     JSInputBarStyleFlat
     
     */
    return JSInputBarStyleFlat;
}

//  Optional delegate method
//  Required if using `JSMessagesViewTimestampPolicyCustom`
//
- (BOOL)hasTimestampForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [[_timestampArray objectAtIndex:indexPath.row] boolValue];
}

- (BOOL)hasNameForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.type == CDChatRoomTypeGroup) {
        return YES;
    }
    return NO;
}

#pragma mark - Messages view data source
- (NSString *)textForRowAtIndexPath:(NSIndexPath *)indexPath {
//    if([[self.messageArray objectAtIndex:indexPath.row] objectForKey:@"Text"]){
//        return [[self.messageArray objectAtIndex:indexPath.row] objectForKey:@"Text"];
//    }
    return [[self.messages objectAtIndex:indexPath.row] objectForKey:@"message"];
}

- (NSDate *)timestampForRowAtIndexPath:(NSIndexPath *)indexPath {
//    return [self.timestamps objectAtIndex:indexPath.row];
    NSDate *time = [[self.messages objectAtIndex:indexPath.row] objectForKey:@"time"];
    return time;
}

- (NSString *)nameForRowAtIndexPath:(NSIndexPath *)indexPath {
    //    return [self.timestamps objectAtIndex:indexPath.row];
    NSString *name = [[self.messages objectAtIndex:indexPath.row] objectForKey:@"fromid"];
    return name;
}

- (UIImage *)avatarImageForIncomingMessage {
    return [UIImage imageNamed:@"demo-avatar-jobs"];
}

- (SEL)avatarImageForIncomingMessageAction {
    return @selector(onInComingAvatarImageClick);
}

- (void)onInComingAvatarImageClick {
    NSLog(@"__%s__",__func__);
}

- (SEL)avatarImageForOutgoingMessageAction {
    return @selector(onOutgoingAvatarImageClick);
}

- (void)onOutgoingAvatarImageClick {
    NSLog(@"__%s__",__func__);
}

- (UIImage *)avatarImageForOutgoingMessage
{
    return [UIImage imageNamed:@"demo-avatar-woz"];
}

- (id)dataForRowAtIndexPath:(NSIndexPath *)indexPath{
//    if([[self.messageArray objectAtIndex:indexPath.row] objectForKey:@"Image"]){
//        return [[self.messageArray objectAtIndex:indexPath.row] objectForKey:@"Image"];
//    }
    return nil;
    
}

- (void)messageUpdated:(NSNotification *)notification {
    NSArray *messages = nil;
    if (self.type == CDChatRoomTypeGroup) {
        NSString *groupId = self.group.groupId;
        if (!groupId) {
            return;
        }
        messages = [[CDSessionManager sharedInstance] getMessagesForGroup:groupId];
    } else {
        messages = [[CDSessionManager sharedInstance] getMessagesForPeerId:self.otherId];
    }
    self.messages = messages;
    [self refreshTimestampArray];
    [self.tableView reloadData];
    [self scrollToBottomAnimated:YES];
}

- (void)sessionUpdated:(NSNotification *)notification {
    if (self.type == CDChatRoomTypeGroup) {
        NSString *title = @"group";
        if (self.group.groupId) {
            title = [NSString stringWithFormat:@"group:%@", self.group.groupId];
        }
        self.title = title;
    }
}
@end
