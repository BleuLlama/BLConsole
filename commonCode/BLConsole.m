//
//  BLConsole.m
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
#import <CoreFoundation/CoreFoundation.h>
#include <sys/socket.h>
#include <netinet/in.h>
#if TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif

#import "BLConsole.h"

void _AcceptCallBack(CFSocketRef socket, CFSocketCallBackType type, 
                     CFDataRef address, const void * data, void * info);

@interface BLConsole()

- (void) handleCallBack:(CFSocketRef) socket
                   Type:(CFSocketCallBackType) type
                Address:(CFDataRef) address
                   Data:(const void *) data
                   Info:(void *) info;

- (void) removeNewlines:(char *) b;
- (int) handleLine:(char *)b WriteStream:(CFWriteStreamRef) writeStream;

@end


@implementation BLConsole

@synthesize port;
@synthesize cmdDelegate, varDelegate;

#pragma mark - Classy stuff
- (id) initWithBasePort:(int)p
{
	self = [super init];
	if( self ) {
		self.port = p;
	}
	return self;
}

- (void) dealloc
{
	[super dealloc];
}

#pragma mark - helpers

- (void) removeNewlines:(char *) b
{
	if( !b ) return;
    
	while(   (b[strlen( b )-1] == '\n')
	      || (b[strlen( b )-1] == '\r')) b[strlen(b)-1] = '\0';
}



#pragma mark - handlers


- (int) sendString:(NSString *) str toStream:(CFWriteStreamRef) writeStream
{
	int bytes = 0;
    
	if( !str ) return 0;
    
	const char * cstr = [str UTF8String];
	char * txt = (char *)cstr;
    
	/* NOTE: REWRITE THIS TO USE DIRECT INDEXING, RATHER THAN C-STRING CONVERSION */
    
	/* the stock routine seems to drop the last character, so
     i rewrote it here to push out one byte at a time. 
     it's slower, but reliable
     */
	while( *txt ) {
		if( CFWriteStreamCanAcceptBytes( writeStream )) {
			bytes = CFWriteStreamWrite( writeStream, (const UInt8*) txt, 1 );
			if( bytes < 0 ) {
			    fprintf(stderr, "CFWriteStreamWrite() failed\n");
			    return 1;
			}
		}
		txt++;
	}
    
	return 0;
}


- (int) sendStringLn:(NSString *) str toStream:(CFWriteStreamRef) writeStream
{
	int ret = [self sendString:str toStream:writeStream];
	if( ret ) return ret;
	return [self sendString:@"\n\r" toStream:writeStream];
}



/* ********************************************************************** */
#pragma mark - internal core command handlers

- (int) handleExit:(char **)argv 
              argc:(int)ac toStream:(CFWriteStreamRef) writeStream
{
	[self sendStringLn:@"Goodbye" toStream:writeStream];
	return 1;
}


- (int) handleVersion:(char **)argv 
                 argc:(int)ac toStream:(CFWriteStreamRef) writeStream
{
	[self sendStringLn:@"   **** BLConsole v1 ****" toStream:writeStream];
	[self sendStringLn:@"READY." toStream:writeStream];
	[self sendStringLn:@" " toStream:writeStream];
	return 0;
}



- (int) handleGetAll:(char **)argv 
                argc:(int)ac toStream:(CFWriteStreamRef) writeStream
{
	int i = 0;
	NSString * key;
    
	[self sendStringLn:@"All keys:" toStream:writeStream];
    
	/* first, iterate over ourself */
	key = [self BLConsole:self GetKey:i++];
	while( key )
	{
		long val = [self BLConsole:self GetLong:key];
		[self sendStringLn:[NSString stringWithFormat:@"  %12@ = %ld", key, val] toStream:writeStream];
        
		key = [self BLConsole:self GetKey:i++];
	}
    
	/* next. iterate over the delegate */
	if( !self.varDelegate ) return 0;
    
	i=0;
	key = [self.varDelegate BLConsole:self GetKey:i++];
	while( key )
	{
		long val = [self BLConsole:self GetLong:key];
		[self sendStringLn:[NSString stringWithFormat:@"  %12@ = %ld", key, val] toStream:writeStream];
        
		key = [self.varDelegate BLConsole:self GetKey:i++];
	}
    
	return 0;
}



- (int) handleGet:(char **)argv 
             argc:(int)ac toStream:(CFWriteStreamRef) writeStream
{
    // NOTE: don't do checks on the parameter list, since handleSet::: also calls this with the same 
    // parameters.  That is, we can get:
    //  get VAR     - correct syntax
    //  set VAR BAZ - incorrect syntax, but called this way from set, to get us to print out the result
    
    
    // argv[0] is get
    // argv[1] is key
    
    NSString * key = [NSString stringWithFormat:@"%s", argv[1]];
    long val = 0;
    bool found = NO;
    
    // first, the internal one
    if( [self BLConsole:self HandlesVariable:key] ) {
        val = [self BLConsole:self GetLong:key];
        found = YES;
    }
    
    // then the external
    if( [self.varDelegate BLConsole:self HandlesVariable:key] ) {
        val = [self.varDelegate BLConsole:self GetLong:key];
        found = YES;
    }
    
    if( !found ) {
        [self sendStringLn:@"Variable not found" toStream:writeStream];
    } else {
		[self sendStringLn:[NSString stringWithFormat:@"  %12@ = %ld", key, val] toStream:writeStream];
    }
    
    return 0;
}

- (int) handleSet:(char **)argv 
             argc:(int)ac toStream:(CFWriteStreamRef) writeStream
{
    bool affected = NO;
    
    // argv[0] is set
    // argv[1] is key
    // argv[2] is value
    
    NSString * key = [NSString stringWithFormat:@"%s", argv[1]];
    long value = atol( argv[2] );
    
    // first, the internal one
    if( [self BLConsole:self HandlesVariable:key] ) {
        [self BLConsole:self SetLong:key Value:value];
        affected = YES;
        [self BLConsole:self KeyChanged:key Value:value];
    }
    
    // then the delegate
    if( [self.varDelegate BLConsole:self HandlesVariable:key] ) {
        [self.varDelegate BLConsole:self SetLong:key Value:value];
        affected = YES;
        [self BLConsole:self KeyChanged:key Value:value];
    }
    
    if( !affected )
    {
        [self sendStringLn:@"Variable not found" toStream:writeStream];
    } else {
        [self handleGet:argv argc:ac toStream:writeStream];
    }
    
	return 0;
}


/* **************************************** */


- (int) handleHelp:(char **)argv 
              argc:(int)ac toStream:(CFWriteStreamRef) writeStream
{
	/* just iterate over the two objects (self and delegate) and print out help */
	int i=0;
	NSString * str;
    
	[self handleVersion:NULL argc:0 toStream:writeStream];
	[self sendStringLn:@"Available commands:" toStream:writeStream];
    
	/* first ourselves */
	do {
		str = [self BLConsole:self getCommandHelp:i];
		if( str ) {
			[self sendString:@"  " toStream:writeStream];
			[self sendStringLn:str toStream:writeStream];
		}
		i++;
	} while( str );
    
	/* next, our delegate */
	if( !self.cmdDelegate ) return 0;
    
	i=0;
	do {
		str = [self.cmdDelegate BLConsole:self getCommandHelp:i];
		if( str ) {
			[self sendString:@"  " toStream:writeStream];
			[self sendStringLn:str toStream:writeStream];
		}
		i++;
	} while( str );
    
	/* return 0 for no exit */
	return 0;
}


/* **************************************** */

/* handleLine 
 **	returns 1 for disconnect
 */
- (int) handleLine:(char *)b WriteStream:(CFWriteStreamRef) writeStream
{
	int argc = 0;
	char * argv[32];
	char * ts;
    
    
	/* split the input string */
	ts = strtok( b, " " );
	while( ts != NULL ) {
		argv[argc] = ts;
		argc++;
		ts = strtok( NULL, " " );
	}
    
	/* make sure we have something to do */
	if( argc == 0 ) return 0;
    
    
	/* okay, auery all objects to find the one that has the handler */
	/* for now, there are just two -- self and cmdDelegate */
	NSString * av0 = [NSString stringWithFormat:@"%s", argv[0]];
	if( [self BLConsole:self HandlesCommand:av0 argc:argc] ){
		return [self BLConsole:self DoCommand:av0 argc:argc argv:argv toStream:writeStream];
		
	} else if(    self.cmdDelegate 
              && [self.cmdDelegate BLConsole:self HandlesCommand:av0 argc:argc] ){
		return [self.cmdDelegate BLConsole:self DoCommand:av0 argc:argc argv:argv toStream:writeStream];
	}
    
	/* not found... let's report an error and go on */
	[self sendStringLn:[NSString stringWithFormat:@"%s: command not found. 'help' for list of commands", argv[0] ] 
              toStream:writeStream];
    
	return 0;
}


#pragma mark - connection

- (void) handleCallBack:(CFSocketRef) socket
                Address:(CFDataRef) address
                   Sock:(CFSocketNativeHandle) sock
{
	CFReadStreamRef readStream = NULL;
	CFWriteStreamRef writeStream = NULL;
	CFIndex bytes;
	UInt8 buffer[128];
	UInt8 recv_len = 0;    
    
	/* Create the read and write streams for the socket */
	CFStreamCreatePairWithSocket(kCFAllocatorDefault, sock,
                                 &readStream, &writeStream);
    
	if (!readStream || !writeStream) {
		close(sock);
		fprintf(stderr, "CFStreamCreatePairWithSocket() failed\n");
		return;
	}
    
	CFReadStreamOpen(readStream);
	CFWriteStreamOpen(writeStream);
    
	int keepOpen = 1;
	buffer[0] = '\0'; /* no previous one */
    
	/* display version/connection information to the connectee */
	[self handleVersion:NULL argc:0 toStream:writeStream];
    
	while( keepOpen ) 
	{
		/* get text from the user */
		int errors = 0;
		errors += [self sendString:@">: " toStream:writeStream ];
		
		memset(buffer, 0, sizeof(buffer));
		while (!strchr((char *) buffer, '\n') && recv_len < sizeof(buffer)) 
		{
			bytes = CFReadStreamRead(readStream, buffer + recv_len, sizeof(buffer) - recv_len);
			if (bytes < 0) {
				fprintf(stderr, "CFReadStreamRead() failed: %d\n", (int)bytes);
				close(sock);
				return;
			}
			recv_len += bytes;
		}
		recv_len = 0;
        
		[self removeNewlines:(char *)buffer];
        
		
		if( [self handleLine:(char *)buffer WriteStream:writeStream] )
		{
			keepOpen = 0;
		}
        
		if( errors ) {
			close( sock );
			keepOpen = 0;
		}
        
	}
    
	close(sock);
	CFReadStreamClose(readStream);
	CFWriteStreamClose(writeStream);
	return;
}


/* AcceptCallBack
 **	springboard C function that decodes the console class from the info
 **	it's like doing pthreads with C++ all over again. 
 **	FUN!
 **	Note: Not really fun.
 */
void _AcceptCallBack(CFSocketRef socket, CFSocketCallBackType type, 
                     CFDataRef address, const void * data, void * info)
{
	NSAutoreleasePool * localPool = [NSAutoreleasePool new];
	BLConsole * blcon = (BLConsole *)info;
	if( type == kCFSocketAcceptCallBack )
	{
        CFSocketNativeHandle sock = *(CFSocketNativeHandle *) data;
		[blcon handleCallBack:socket Address:address Sock:sock];
	}
	[localPool release];
}


/* connect_actual
 **	connect up to our specified port
 **	it will incrememnt the port number if necessary
 */
- (void) connect
{
	long startPort = self.port;
    
	/* The server socket */
	CFSocketRef TCPServer;
    
	/* Used by setsockopt */
	int yes = 1;
    
	/* Build our socket context; */
	CFSocketContext CTX = { 0, self, NULL, NULL, NULL };
    
	/* Create the server socket as a TCP IPv4 socket and set a callback */
	/* for calls to the socket's lower-level accept() function */
	TCPServer = CFSocketCreate(NULL, PF_INET, SOCK_STREAM, IPPROTO_TCP,
                               kCFSocketAcceptCallBack, (CFSocketCallBack)_AcceptCallBack, &CTX);
	if (TCPServer == NULL)
	    return; /* failure */
    
	/* Re-use local addresses, if they're still in TIME_WAIT */
	setsockopt(CFSocketGetNative(TCPServer), SOL_SOCKET, SO_REUSEADDR,
               (void *)&yes, sizeof(yes));
    
	/* Set the port and address we want to listen on */
	struct sockaddr_in addr;
	memset(&addr, 0, sizeof(addr));
	addr.sin_len = sizeof(addr);
	addr.sin_family = AF_INET;
	addr.sin_addr.s_addr = htonl(INADDR_ANY);
    
	int portOK = 0;
	while( !portOK ) 
	{ 
	    addr.sin_port = htons( self.port );
        
	    NSData *address = [ NSData dataWithBytes: &addr length: sizeof(addr) ];
        
	    if (CFSocketSetAddress(TCPServer, (CFDataRef) address) != kCFSocketSuccess) {
            fprintf(stderr, "CFSocketSetAddress() failed for port %d\n", self.port);
            
            if( self.port > startPort + 10 ) {
                CFRelease(TCPServer);
                return; /* failure */
            } else {
                self.port++;
            }
	    } else {
		    portOK = 1;
	    }
	}
    
	CFRunLoopSourceRef sourceRef =
    CFSocketCreateRunLoopSource(kCFAllocatorDefault, TCPServer, 0);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), sourceRef, kCFRunLoopCommonModes);
    CFRelease(sourceRef);
    
	printf("Socket listening on port ;%d\n", self.port);
}


/* disconnect
 **	disconnect the socket and such.
 */
- (void) disconnect
{
	/* TBD */
}



#pragma mark - BLConsoleCommandDelegate

typedef struct fitem {
	NSString * argv0;
	int argc;
	NSString * help;
} fitem;

fitem fitems[20] =
{
	/// doesn't work.  need to make this dynamic i think
	{ @"version", 1, @"version       display version info" },
	{ @"exit",    1, @"exit          disconnect" },
    
	{ @"help",    1, @"help          display this help information" },
    
	{ @"getall",  1, @"getall        display all variables" },
	{ @"get",     2, @"get KEY       display the specified variable" },
	{ @"set",     3, @"set KEY VAL   change the value of KEY to VAL" },
    
	{ nil }
};

/* enumeration */
- (bool) BLConsole:(BLConsole *)blc HandlesCommand:(NSString *)cmd argc:(int)ac
{
	// implement this in your class however you'd like.
	int x=0;
	while( fitems[x].argv0 != nil ) {
		if(   ( [fitems[x].argv0 caseInsensitiveCompare:cmd] == NSOrderedSame )
		   && ( fitems[x].argc == ac )) {
			return YES;
		}
		x++;
	}
	return NO;
}

- (NSString *) BLConsole:(BLConsole *)blc getCommand:(int)cid
{
	// implement this in your class however you'd like.
	int x=0;
	while( fitems[x].argv0 != nil ) {
		if( x == cid ) return fitems[x].argv0;
		x++;
	}
	return nil;
}

- (NSString *) BLConsole:(BLConsole *)blc getCommandHelp:(int)cid
{
	// implement this in your class however you'd like.
	int x=0;
	while( fitems[x].argv0 != nil ) {
		if( x == cid ) return fitems[x].help;
		x++;
	}
	return nil;
}

/* execution */
- (int) BLConsole:(BLConsole *)blc
		DoCommand:(NSString *)cmd
             argc:(int)ac
             argv:(char **)av
         toStream:(CFWriteStreamRef) writeStream
{
	/* just a stupid hardcoded if-else thing */
	if( [cmd caseInsensitiveCompare:@"help"] == NSOrderedSame ) {
		return [self handleHelp:av argc:ac toStream:writeStream];
	} else if( [cmd caseInsensitiveCompare:@"exit"] == NSOrderedSame ) {
        return [self handleExit:av argc:ac toStream:writeStream];
    } else if( [cmd caseInsensitiveCompare:@"version"] == NSOrderedSame ) {
        return [self handleVersion:av argc:ac toStream:writeStream];
    } else if( [cmd caseInsensitiveCompare:@"getall"] == NSOrderedSame ) {
        return [self handleGetAll:av argc:ac toStream:writeStream];
    } else if( [cmd caseInsensitiveCompare:@"get"] == NSOrderedSame ) {
        return [self handleGet:av argc:ac toStream:writeStream];
    } else if( [cmd caseInsensitiveCompare:@"set"] == NSOrderedSame ) {
        return [self handleSet:av argc:ac toStream:writeStream];
    } 
	return 0;
}


#pragma mark - BLConsoleVariableDelegate


typedef struct vitem {
	NSString * key;
	long value;
} vitem;


vitem vitems[10] = {
	{ @"banana", 42 },
	{ @"burrito", 9999 },
	{ @"orange", 0 },
	{ nil }
};

/* enumeration */
- (bool) BLConsole:(BLConsole *)blc HandlesVariable:(NSString *)key
{
	// implement this in your class however you'd like.
	int x=0;
	while( vitems[x].key != nil ) {
		if( [vitems[x].key caseInsensitiveCompare:key] == NSOrderedSame ) {
			return YES;
		}
		x++;
	}
	return NO;
}


- (NSString *) BLConsole:(BLConsole *)blc GetKey:(int)kid
{
	// implement this in your class however you'd like.
	int x=0;
	while( vitems[x].key != nil ) {
		if( x==kid ) return vitems[x].key;
		x++;
	}
	return nil;
}

/* execution */
- (long) BLConsole:(BLConsole *)blc GetLong:(NSString *)key
{
	// implement this in your class however you'd like.
	int x=0;
	while( vitems[x].key != nil ) {
		if( [vitems[x].key caseInsensitiveCompare:key] == NSOrderedSame ) {
			return vitems[x].value;
		}
		x++;
	}
	return 0l;
}

- (void) BLConsole:(BLConsole *)blc SetLong:(NSString *)key Value:(long)v
{
	// implement this in your class however you'd like.
	int x=0;
	while( vitems[x].key != nil ) {
		if( [vitems[x].key caseInsensitiveCompare:key] == NSOrderedSame ) {
			vitems[x].value = v;
			return;
		}
		x++;
	}
}


- (void) BLConsole:(BLConsole *)blc KeyChanged:(NSString *)key Value:(long)v
{
	// notification doojobby.
	NSLog( @"The variable \"%@\" changed to %ld\n", key, v );
}
@end

