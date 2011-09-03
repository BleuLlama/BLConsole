//
//  ConsoleTestViewController.m
//  ConsoleTest
//
//  Created by Scott Lawrence on 9/3/11.
//  Copyright 2011 Scott Lawrence. All rights reserved.
//

#import "ConsoleTestViewController.h"

@implementation ConsoleTestViewController

@synthesize blc;

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)updateDisplay
{
    portText.text = [NSString stringWithFormat:@"%ld", self.blc.port];
    testval.text = [NSString stringWithFormat:@"%ld", tv];
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
    self.blc = [[BLConsole alloc] initWithBasePort:4567];
    [self.blc connect];
    self.blc.cmdDelegate = self;
    self.blc.varDelegate = self;
    
    [self updateDisplay];
    
    [super viewDidLoad];
}

- (void)viewDidUnload
{
    [self.blc disconnect];
    self.blc = nil;
    
    
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}



#pragma mark - BLConsoleVariableDelegate functions

/* enumeration */
- (bool) BLConsole:(BLConsole *)blc HandlesVariable:(NSString *)key
{
    if( [key caseInsensitiveCompare:@"testval"] == NSOrderedSame ) return YES;
	return NO;
}


- (NSString *) BLConsole:(BLConsole *)blc GetKey:(int)kid
{
    if( kid == 0 ) return @"testval";
	return nil;
}

/* execution */
- (long) BLConsole:(BLConsole *)blc GetLong:(NSString *)key
{
    if( [key caseInsensitiveCompare:@"testval"] == NSOrderedSame ) return tv;
	return 0l;
}

- (void) BLConsole:(BLConsole *)blc SetLong:(NSString *)key Value:(long)v
{
    if( [key caseInsensitiveCompare:@"testval"] == NSOrderedSame ) tv = v;
    [self updateDisplay];
}


- (void) BLConsole:(BLConsole *)blc KeyChanged:(NSString *)key Value:(long)v
{
	// notification doojobby.
	NSLog( @"The variable \"%@\" changed to %ld\n", key, v );
    [self updateDisplay];
}



#pragma mark - BLConsoleCommandDelegate

/* enumeration */
- (bool) BLConsole:(BLConsole *)blc HandlesCommand:(NSString *)cmd argc:(int)ac
{
    if( ([cmd caseInsensitiveCompare:@"update"] == NSOrderedSame) && (ac == 1) ) return YES;
	return NO;
}

- (NSString *) BLConsole:(BLConsole *)blc getCommand:(int)cid
{
    if( cid == 0 ) return @"update";
    return nil;
}

- (NSString *) BLConsole:(BLConsole *)blc getCommandHelp:(int)cid
{
    if( cid == 0 ) return @"update  update all screen values";
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
	if( [cmd caseInsensitiveCompare:@"update"] == NSOrderedSame ) {
        [self updateDisplay];
		return 0;
	}
	return 0;
}

@end
