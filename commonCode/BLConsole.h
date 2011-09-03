//
//  BLConsole.h
//  ConsoleTest
//
//  Created by Scott Lawrence on 9/3/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

////////////////////////////////////////
// Delegate protocols

@class BLConsole;

@protocol BLConsoleCommandDelegate <NSObject>
/* enumeration */
- (bool) BLConsole:(BLConsole *)blc HandlesCommand:(NSString *)cmd argc:(int)ac;
- (NSString *) BLConsole:(BLConsole *)blc getCommand:(int)cid;
- (NSString *) BLConsole:(BLConsole *)blc getCommandHelp:(int)cid;

/* execution */
- (int) BLConsole:(BLConsole *)blc
		DoCommand:(NSString *)cmd
             argc:(int)ac
             argv:(char **)av
         toStream:(CFWriteStreamRef) writeStream;

@end

@protocol BLConsoleVariableDelegate <NSObject>
/* enumeration */
- (bool) BLConsole:(BLConsole *)blc HandlesVariable:(NSString *)key;
- (NSString *) BLConsole:(BLConsole *)blc GetKey:(int)kid;

/* execution */
- (long) BLConsole:(BLConsole *)blc GetLong:(NSString *)key;
- (void) BLConsole:(BLConsole *)blc SetLong:(NSString *)key Value:(long)v;

/* change notification */
- (void) BLConsole:(BLConsole *)blc KeyChanged:(NSString *)key Value:(long)v;
@end


// the main class.

@interface BLConsole : NSObject 
<BLConsoleCommandDelegate, BLConsoleVariableDelegate>
{
	int port;
	NSMutableArray * commands;
	id <BLConsoleCommandDelegate> cmdDelegate;
	id <BLConsoleVariableDelegate> varDelegate;
}

@property (nonatomic) int port;
@property (nonatomic, assign) id <BLConsoleCommandDelegate> cmdDelegate;
@property (nonatomic, assign) id <BLConsoleVariableDelegate> varDelegate;

- (id) initWithBasePort:(int)p;

- (void) connect;
- (void) disconnect;

- (void) handleCallBack:(CFSocketRef) socket
                   Type:(CFSocketCallBackType) type
                Address:(CFDataRef) address
                   Data:(const void *) data
                   Info:(void *) info;

- (void) removeNewlines:(char *) b;
- (int) handleLine:(char *)b WriteStream:(CFWriteStreamRef) writeStream;
@end