//
//  ConsoleTestViewController.h
//  ConsoleTest
//
//  Created by Scott Lawrence on 9/3/11.
//  Copyright 2011 Scott Lawrence. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BLConsole.h"

@interface ConsoleTestViewController : UIViewController
<BLConsoleCommandDelegate, BLConsoleVariableDelegate>
{
    BLConsole * blc;
    
    IBOutlet UILabel * portText;
    IBOutlet UILabel * testval;
    
    long tv;
}

@property (nonatomic, retain ) BLConsole * blc;
@end
