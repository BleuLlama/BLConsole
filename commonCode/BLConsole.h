//
//  BLConsole.h
//  ConsoleTest
//
//  Created by Scott Lawrence on 9/3/11.
//  Copyright 2011 Scott Lawrence. All rights reserved.
//

// Copyright (C) 2011 by Scott Lawrence
// (MIT License)
// 
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject
// to the following conditions:
// 
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
// IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR
// ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
// CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


#import <Foundation/Foundation.h>

// NOTE: current implementation blocks on the main runloop. This is bad.
//       Need to upgrade this to use NSStream.
//       eg: http://stackoverflow.com/questions/4930957/nsstream-and-sockets-nsstreamdelegate-methods-not-being-called

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

@end
