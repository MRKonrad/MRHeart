//
//  MRHeartFilter.h
//  MRHeart
//
//  Copyright (c) 2014 Konrad. All rights reserved.
//

#include <Foundation/Foundation.h>
#include <Accelerate/Accelerate.h>

#import <OsiriXAPI/AppController.h>
#import <OsiriXAPI/BrowserController.h>
#import <OsiriXAPI/DicomStudy.h>
#import <OsiriXAPI/DicomSeries.h>
#import <OsiriXAPI/DicomImage.h>
#import <OsiriXAPI/PluginFilter.h>

#import "DCMObject.h"
#import "DCMAttribute.h"
#import "DCMAttributeTag.h"

@interface MRHeartFilter : PluginFilter {
    
    IBOutlet NSWindow *mrWindow;
    IBOutlet NSTextField *BSAfield;
    IBOutlet NSTextField *units;
    IBOutlet NSTextField *LVparams;
    IBOutlet NSTextField *LVBSAparams;
    IBOutlet NSTextField *RVparams;
    IBOutlet NSTextField *RVBSAparams;
    IBOutlet NSTextField *ES;
    IBOutlet NSTextField *ED;
    
    //variables
    NSArray *slicesNormalVectors;
    NSArray *sliceOrientation;
    NSArray *sliceThickenss;
    NSArray *areaTableLVENDO;
    NSArray *areaTableLVEPI;
    NSArray *areaTableRVENDO;
    NSArray *areaTableRVEPI;
    NSArray *volumeTableLVENDO;
    NSArray *volumeTableLVEPI;
    NSArray *volumeTableRVENDO;
    NSArray *volumeTableRVEPI;
}

// ###############################
// plugin functions
// ###############################
-(long)     filterImage:(NSString*) menuName;

// ###############################
// browser controler functions
// ###############################

//this function is slightly modified copy of viewerDICOMInt from browser controller
- (void) openNewViewerKW;

// this function is slightly modified copy of processOpenViewerDICOMFromArray from browser controller
- (void) processOpenViewerDICOMFromArrayKW:(NSArray*) toOpenArray movie:(BOOL) movieViewer viewer: (ViewerController*) viewer;

// ###############################
// calculation functions
// ###############################
-(float)            calcBSA;
-(double)           calcDistanceBetweenSlices:(int) islice0 and: (int) islice1;
-(void)             crossProduct:(double[3]) v1 and:(double[3]) v2 result:(double[3]) vR;
-(double)           dotProduct:(double[3]) v1 and:(double[3]) v2;
-(NSMutableArray *) getAreaArrayFor:(NSString *) RoiName;
-(void)             normalize:(double[3]) v1 result:(double[3]) vR;
-(long)             myparseConFile: (NSString*) mypath;

// ###############################
// GUI functions
// ###############################

-(IBAction) calcVolumes:(id)sender;
-(NSMutableArray *)calcVolumesNew:(NSString*) RoiName;
-(IBAction) myDrawROI:(id)sender;
-(IBAction) myImport:(id)sender;

@end
