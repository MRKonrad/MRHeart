//
//  MRHeartWindowController.h
//  MRHeart
//
//  Created by Konrad on 01/06/14.
//
//

#import <Cocoa/Cocoa.h>
#import "MRHeartFilter.h";

@interface MRHeartWindowController : NSWindowController{
    ViewerController	*viewer;
    //IBOutlet NSWindow   *mrWindow;
}
-(IBAction) calcVolumes:(id)sender;
-(IBAction) drawLVEpi:(id)sender;
-(IBAction) drawLVEndo:(id)sender;
-(IBAction) drawRVEpi:(id)sender;
-(IBAction) drawRVEndo:(id)sender;

@end
