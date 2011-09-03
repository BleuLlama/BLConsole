//
//  ConsoleTestAppDelegate.h
//  ConsoleTest
//
//  Created by Scott Lawrence on 9/3/11.
//  Copyright 2011 Scott Lawrence. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ConsoleTestViewController;

@interface ConsoleTestAppDelegate : NSObject <UIApplicationDelegate>

@property (nonatomic, retain) IBOutlet UIWindow *window;

@property (nonatomic, retain) IBOutlet ConsoleTestViewController *viewController;

@end
