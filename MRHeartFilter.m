//
//  MRHeartFilter.m
//  MRHeart
//
//  Copyright (c) 2014 Konrad Werys. All rights reserved.
//

/** TODO:
 1. how to check if image is changed?
 2. bsa calculation on given weight and height, not just automatic
 3. interpolation of rois between end systole and end diastole !
 4. show which frames have contours (in table?) !
 5. export contures to qmass
 6. correct import contures from qmass (indicate slice position etc)
 7. Mass is calculated from ED frame. Print the mass as the biggest mass of all frames.
 */
 

#import "MRHeartFilter.h"

@implementation MRHeartFilter

// variables constant for the whole file
int const nmyROIs = 4;
NSString* const myROINames [] = {@"LVEPI",@"LVENDO",@"RVEPI",@"RVENDO"};
RGBColor const myROIColors[] = {
    {0, 65535, 0},
    {65535, 0, 0},
    {65535, 65535, 0},
    {0, 65535, 65535}};

- (void) initPlugin
{
}

/**
 main plugin function
 */
- (long) filterImage:(NSString*) menuName
{
    [self openNewViewerKW];
    viewerController = [ViewerController frontMostDisplayed2DViewer];
    
    // Window Controller
    NSWindowController *window = [[NSWindowController alloc] initWithWindowNibName:@"MRHeartPanel" owner:self];
    [window showWindow:self];

//    How to make keyboard work
//    NSLog(@"WC first responder %d",[window acceptsFirstResponder]);
//    NSLog(@"VC first responder %d",[viewerController acceptsFirstResponder]);
//    NSLog(@"mrW %d",[mrWindow acceptsFirstResponder]);

    // calc BSA and dispalay
    NSString *BSAstring = [NSString stringWithFormat:@"%.2f", [self calcBSA]];
    [BSAfield setStringValue: BSAstring];
    
    // get normal vectors,
    [units setStringValue:@""];
    [LVparams setStringValue:@"LV:\n0\n0\n0\n0\n0\n"];
    [LVBSAparams setStringValue:@"NLV:\n0\n0\n0\n0\n0\n"];
    [RVparams setStringValue:@"RV:\n0\n0\n0\n0\n0\n"];
    [RVBSAparams setStringValue:@"NRV:\n0\n0\n0\n0\n0\n"];
    
    // set ES and ED
    [self autoSetESED:0];
    
    return 0; // No Errors
}

/*
 plugin calculation functions
 */

/** sets end systolic and end diastolic based on volume of LVENDO. If no volumes in LVENDO, sets ED=1, ES=ntimes/2
 */
-(IBAction)autoSetESED:(id)sender;
{
    //if volumes are set
    NSMutableArray *volumesArrayLVENDO = [self calcVolumesNew:@"LVENDO"];

    NSNumber *mymax = [NSNumber numberWithDouble:-MAXFLOAT];
    NSNumber *mymin = [NSNumber numberWithDouble:MAXFLOAT];
    int mymaxIDX = 0;
    int myminIDX = 0;
    for (int i = 0; i < [volumesArrayLVENDO count]; i++)
    {
        NSNumber *temp = [volumesArrayLVENDO objectAtIndex:i];
        if (([temp doubleValue] < [mymin doubleValue]) && ([temp doubleValue]!=0)) {
            mymin = temp;
            myminIDX = i;
        }
        if ([temp doubleValue] > [mymax doubleValue]){
            mymax = temp;
            mymaxIDX = i;
        }
    }
    
    NSLog(@"Min:%@ %i Max:%@ %i",mymin,myminIDX,mymax,mymaxIDX);
    
    if (([mymin doubleValue]!=0) && ([mymax doubleValue]!=0)){
        ED.intValue = mymaxIDX  + 1;
        ES.intValue = myminIDX + 1;
    } else{
        ED.intValue = 1;
        ES.intValue = [[viewerController pixList] count]/2+1;
    }
}

/**
 Takes patient parameters and calculates BSA
 from http://en.wikipedia.org/wiki/Body_surface_area
 */
-(float) calcBSA
{
    float BSA = 0;
    
    @try{
        // get first image
        NSArray     *PixList = [viewerController pixList: 0];
        DCMPix      *curPix = [PixList objectAtIndex: 0];
        // get dicom object
        DCMObject   *dcmObj = [DCMObject objectWithContentsOfFile:[curPix sourceFile] decodingPixelData:NO];
        DCMAttributeTag *patientsWeightTag = [DCMAttributeTag tagWithName:@"PatientsWeight"];
        DCMAttributeTag *patientsSizeTag = [DCMAttributeTag tagWithName:@"PatientsSize"];
        // get data from dicom tags
        float patientsWeight = [[[[dcmObj attributeForTag:patientsWeightTag] value] description] doubleValue];
        float patientsSize   = [[[[dcmObj attributeForTag:patientsSizeTag] value] description] doubleValue];
        BSA=sqrt(patientsWeight*patientsSize)/6;
        
    } @catch (NSException *exception){
        NSLog(@"BSA calculation exception: %@",exception);
    }
    return BSA;
}

/**
 do not check if parallel, this should be checked before
 in fact we are looking for distance between point(origin of slice0) and plane (normal vector and origin of slice1)
 distance as in http://en.wikipedia.org/wiki/Plane_(geometry)#Distance_from_a_point_to_a_plane
 */
-(double) calcDistanceBetweenSlices:(int) islice0 and: (int) islice1
{
    double sliceDistance = 0;
    // get PixList for given slices
    NSArray     *PixList0 = [viewerController pixList: islice0];
    NSArray     *PixList1 = [viewerController pixList: islice1];
    
    // get first image objects in selected slice
    DCMPix      *curPix0 = [PixList0 objectAtIndex: 0];
    DCMPix      *curPix1 = [PixList1 objectAtIndex: 0];
    
    // get orientation (to use myorientation1[6-8] as normal vector)
    double      myorientation1[9];
    [curPix1 orientationDouble: myorientation1];
    
    double      sliceOrigins0[3] = {[curPix0 originX],[curPix0 originY],[curPix0 originZ]};
    double      sliceOrigins1[3] = {[curPix1 originX],[curPix1 originY],[curPix1 originZ]};
    // substract orientation point vectors
    double      tempp[3] = {sliceOrigins0[0] - sliceOrigins1[0], sliceOrigins0[1] - sliceOrigins1[1], sliceOrigins0[2] - sliceOrigins1[2]};
    // get normal vector (slice1)
    double      tempnormal1[3] = {myorientation1[6],myorientation1[7],myorientation1[8]};

    sliceDistance = [self dotProduct: tempnormal1 and: tempp];
    //NSLog(@"!!!Distance to previous slice: %g",sliceDistance);
    
    return sliceDistance;
}

/** calculating Volumes
 http://mathworld.wolfram.com/Point-PlaneDistance.html
 http://en.wikipedia.org/wiki/Plane_(geometry)#Distance_from_a_point_to_a_plane
 @TODO: I just found that myorientation[6-8] is vector normal to the plane. First loop can be a little shorter
 @TODO: It would be nice to have the slices sorted before volume calculation
 @TODO: First check if planes are parallel, then allow to use plugin
 @TODO: Using number of frames from first slice assuming that all slices have the same number of frames (this is true for 4d viewer, but it should be corrected)
 */
-(NSMutableArray *)calcVolumesNew:(NSString*) RoiName;
{
    // number of slices selected
    int nslices = [viewerController maxMovieIndex];
    // number of frames in first slice
    NSMutableArray     *PixList = [viewerController pixList: 0];
    int ntimes = [PixList count];
    
    // get areaArray
    NSMutableArray *areaArray;
    areaArray =[self getAreaArrayFor:RoiName];
    
    //get slice thicknesses
    double *sliceThickneses = malloc( nslices * sizeof(double) );
    for (int j = 0; j < nslices; j++)
    {
        NSArray     *PixList = [viewerController pixList: j];
        DCMPix      *curPix = [PixList objectAtIndex: 0];
        sliceThickneses[j]=[curPix sliceThickness];
    }
    
    // do I have to initialize an array like this? =/
    NSNumber *temp =[[NSNumber alloc] initWithDouble:0];
    NSMutableArray *myvolume = [[NSMutableArray alloc] initWithCapacity:ntimes ];
    for (int i = 0; i < ntimes; i++)
        [myvolume insertObject:temp atIndex:i];
    
    // calculate volumes
    for (int itime = 0; itime < ntimes; itime++)
    {
        double tempvolume = 0;
        // calculate how many non empty elements there are
        int slicesWithROIcounter=0;
        for (int islice = 0; islice < nslices; islice++){
            if([areaArray objectAtIndex:islice*ntimes+itime]!=0){
                slicesWithROIcounter++;
            }
        }
        // calculate slice with roi indexes
        int *sliceWithRoiIdx = malloc(slicesWithROIcounter*sizeof(int));
        int i = 0;
        for (int islice = 0; islice < nslices; islice++){
            if([areaArray objectAtIndex:islice*ntimes+itime]!=0){
                sliceWithRoiIdx[i++]=islice;
            }
        }
        
        // calculate volumes
        if (slicesWithROIcounter>0){
            int idxFirst = sliceWithRoiIdx[0];
            tempvolume = sliceThickneses[idxFirst] * [[areaArray objectAtIndex:idxFirst*ntimes+itime] floatValue]/2/10;
            for (int i = 0; i<slicesWithROIcounter-1; i++){
                int idx0 = sliceWithRoiIdx[i];
                int idx1 = sliceWithRoiIdx[i+1];
                double mydistance;
                mydistance = [self calcDistanceBetweenSlices:idx0 and:idx1];
                tempvolume = tempvolume + mydistance * [[areaArray objectAtIndex:idx0*ntimes+itime] floatValue]/2/10;
                tempvolume = tempvolume + mydistance * [[areaArray objectAtIndex:idx1*ntimes+itime] floatValue]/2/10;
            }
            int idxLast = sliceWithRoiIdx[slicesWithROIcounter-1];
            tempvolume = tempvolume + sliceThickneses[idxLast] * [[areaArray objectAtIndex:idxLast*ntimes+itime] floatValue]/2/10;
        }
        [myvolume insertObject:[[NSNumber alloc] initWithDouble:tempvolume] atIndex:itime];
        NSLog(@"Frame: %d Volume: %g",itime,tempvolume);
        free(sliceWithRoiIdx);
    }
    return myvolume;
}

-(NSMutableArray *)getAreaArrayFor:(NSString *) RoiName{
    
    // number of slices selected
    int nslices = [viewerController maxMovieIndex];
    // number of frames in first slice
    NSMutableArray     *PixList = [viewerController pixList: 0];
    int ntimes = [PixList count];
    
    // do I have to initialize an array like this? =/
    NSNumber *temp =[[NSNumber alloc] initWithDouble:0];
    NSMutableArray *areaArray = [[NSMutableArray alloc] initWithCapacity:nslices*ntimes ];
    for (int i = 0; i < nslices * ntimes; i++)
        [areaArray insertObject:temp atIndex:i];
    
    // get all Rois with name RoiName
    for (int islice = 0; islice < [viewerController maxMovieIndex]; islice++)
    {
        // All rois contained in the current series
        NSMutableArray  *roiSeriesList  = [viewerController roiList: islice];
        for (int itime = 0; itime < ntimes; itime++)
        {
            // All rois contained in the current image
            NSMutableArray  *roiImageList = [roiSeriesList objectAtIndex: itime];
            for (int i = 0; i < [roiImageList count]; i++)
            {
                ROI *curROI = [roiImageList objectAtIndex: i];
                if ([[curROI name] isEqual:RoiName]){
                    NSNumber *temp = [[NSNumber alloc] initWithFloat:[curROI roiArea]];
                    [areaArray insertObject:temp atIndex:islice*ntimes+itime];
                    NSLog(@"Found %@ ROI. Slice:%d Frame:%d Area:%@",RoiName,islice,itime,[areaArray objectAtIndex:islice*ntimes+itime]);
                }
            }
        }
    }
    return areaArray;
}

/*
 math functions
 Sources:
 http://gatechgrad.wordpress.com/2011/10/08/cross-product/
 */
-(double) dotProduct:(double[3]) v1 and:(double[3]) v2 {
    return  (v1[0] * v2[0] + v1[1] * v2[1] + v1[2] * v2[2]);
}

-(void) crossProduct:(double[3]) v1 and:(double[3]) v2 result:(double[3]) vR {
    vR[0] =   ( (v1[1] * v2[2]) - (v1[2] * v2[1]) );
    vR[1] = - ( (v1[0] * v2[2]) - (v1[2] * v2[0]) );
    vR[2] =   ( (v1[0] * v2[1]) - (v1[1] * v2[0]) );
}

-(void) normalize:(double[3]) v1 result:(double[3]) vR {
    double fMag = sqrt( pow(v1[0], 2) + pow(v1[1], 2) + pow(v1[2], 2));
    vR[0] = v1[0] / fMag;
    vR[1] = v1[1] / fMag;
    vR[2] = v1[2] / fMag;
}

/*
 user interface functions
 */
-(IBAction)calcVolumes:(id)sender;
{
    NSMutableArray *volumesArrayLVEPI = [self calcVolumesNew:@"LVEPI"];
    NSMutableArray *volumesArrayLVENDO = [self calcVolumesNew:@"LVENDO"];
    NSMutableArray *volumesArrayRVEPI = [self calcVolumesNew:@"RVEPI"];
    NSMutableArray *volumesArrayRVENDO = [self calcVolumesNew:@"RVENDO"];
    // check if ES and ED makes sense
    int ntimes = [[viewerController pixList] count];
    int es = [ES intValue];
    int ed = [ED intValue];
    float bsa = [BSAfield floatValue];
    if (bsa == 0) bsa = 1;
    if ((es < 0) || (es > ntimes) || (ed < 0) || (ed > ntimes)){
        NSAlert* msgBox = [[[NSAlert alloc] init] autorelease];
        [msgBox setMessageText: @"Problem with ES or ED"];
        [msgBox addButtonWithTitle: @"OK"];
        [msgBox runModal];
        return;
    }
    double LVESV = [[volumesArrayLVENDO objectAtIndex:es-1] doubleValue];
    double LVEDV = [[volumesArrayLVENDO objectAtIndex:ed-1] doubleValue];
    double LVSV  = LVEDV-LVESV;
    double LVEF  = 100*LVSV/LVEDV;
    double LVm   = 1.05*([[volumesArrayLVEPI objectAtIndex:ed-1] doubleValue] - [[volumesArrayLVENDO objectAtIndex:ed-1] doubleValue]);
    double RVESV = [[volumesArrayRVENDO objectAtIndex:es-1] doubleValue];
    double RVEDV = [[volumesArrayRVENDO objectAtIndex:ed-1] doubleValue];
    double RVSV  = RVEDV-RVESV;
    double RVEF  = 100*RVSV/RVEDV;
    double RVm   = 1.05*([[volumesArrayRVEPI objectAtIndex:ed-1] doubleValue] - [[volumesArrayRVENDO objectAtIndex:ed-1] doubleValue]);
    
    if (LVEDV == 0) LVEF = 0;
    if (RVEDV == 0) RVEF = 0;
    if (LVm < 0) LVm = 0;
    if (RVm < 0) LVm = 0;
    
    NSString *unitsMilli = [NSString stringWithFormat:@"\n[ml]\n[ml]\n[ml]\n[%%]\n[g]"];
    NSString *lvMilli = [NSString stringWithFormat:@"LV:\n%.2f\n%.2f\n%.2f\n%.2f\n%.2f\n",LVESV,LVEDV,LVSV,LVEF,LVm];
    NSString *lvbsaMilli = [NSString stringWithFormat:@"LV/BSA:\n%.2f\n%.2f\n%.2f\n\n%.2f\n",LVESV/bsa,LVEDV/bsa,LVSV/bsa,LVm/bsa];
    NSString *rvMilli = [NSString stringWithFormat:@"RV:\n%.2f\n%.2f\n%.2f\n%.2f\n%.2f\n",RVESV,RVEDV,RVSV,RVEF,RVm];
    NSString *rvbsaMilli = [NSString stringWithFormat:@"RV/BSA:\n%.2f\n%.2f\n%.2f\n\n%.2f\n",RVESV/bsa,RVEDV/bsa,RVSV/bsa,RVm/bsa];
    
    NSString *unitsMicro = [NSString stringWithFormat:@"\n[ul]\n[ul]\n[ul]\n[%%]\n[mg]"];
    NSString *lvMicro = [NSString stringWithFormat:@"LV:\n%.2f\n%.2f\n%.2f\n%.2f\n%.2f\n",LVESV*1000,LVEDV*1000,LVSV*1000,LVEF,LVm*1000];
    NSString *lvbsaMicro = [NSString stringWithFormat:@"LV/BSA:\n%.2f\n%.2f\n%.2f\n\n%.2f\n",LVESV/bsa*1000,LVEDV/bsa*1000,LVSV/bsa*1000,LVm/bsa*1000];
    NSString *rvMicro = [NSString stringWithFormat:@"RV:\n%.2f\n%.2f\n%.2f\n%.2f\n%.2f\n",RVESV*1000,RVEDV*1000,RVSV*1000,RVEF,RVm*1000];
    NSString *rvbsaMicro = [NSString stringWithFormat:@"RV/BSA:\n%.2f\n%.2f\n%.2f\n\n%.2f\n",RVESV/bsa*1000,RVEDV/bsa*1000,RVSV/bsa*1000,RVm/bsa*1000];
    
    if (LVESV < .1 || LVEDV < .1 || LVSV < .1){
        [units setStringValue:unitsMicro];
        [LVparams setStringValue:lvMicro];
        [LVBSAparams setStringValue:lvbsaMicro];
        [RVparams setStringValue:rvMicro];
        [RVBSAparams setStringValue:rvbsaMicro];
    } else {
        [units setStringValue:unitsMilli];
        [LVparams setStringValue:lvMilli];
        [LVBSAparams setStringValue:lvbsaMilli];
        [RVparams setStringValue:rvMilli];
        [RVBSAparams setStringValue:rvbsaMilli];
    }
}

/**
 sets current ROI's name, color, type and mode
 */
-(IBAction)myDrawROI:(id)sender;
{
    // get identifier of sender button
    NSString* buttonIdentifier = [sender identifier];
    NSLog(@"Buton Identifier: %@",buttonIdentifier);
    
    // find index of sender button (to use in const variables myROINames and myROIColors)
    int myROINamesIDX = 0;
    for (int iROI = 0; iROI < nmyROIs; iROI++)
        if ([buttonIdentifier isEqualToString: myROINames[iROI]])
            myROINamesIDX = iROI;
    NSLog(@"ROI name: %d",myROINamesIDX);
    
    // get ROI list from current slice and time frame (roiImageList)
    int         curTimeFrame =  [[viewerController imageView] curImage];
    int         curSlice =  [viewerController curMovieIndex];
    NSMutableArray  *roiSeriesList  = [viewerController roiList: curSlice];
    NSMutableArray  *roiImageList = [roiSeriesList objectAtIndex: curTimeFrame];
    
    // change ROI tool to tcpolygon
    [viewerController setROIToolTag:tCPolygon];
    
    // loop over ROIs
    for (int i = 0; i < [roiImageList count]; i++)
    {
        // find selected/drawing roi
        ROI *curROI = [roiImageList objectAtIndex: i];
        if (([curROI ROImode]==ROI_selected) || ([curROI ROImode]==ROI_selectedModify) || ([curROI ROImode]==ROI_drawing)){
            // set ROI name
            [curROI setName: myROINames[myROINamesIDX]];
            // ser ROI color
            [curROI setColor: myROIColors[myROINamesIDX]];
            // if roiMode was ROI_drawing, change to ROI_selected
            [curROI setROIMode:ROI_selected];
            // change ROI tool to tcpolygon
            [viewerController setROIToolTag:tCPolygon];
            
            NSLog(@"Selected ROI area: %g, mode: %ld",[curROI roiArea], [curROI ROImode]);
        }
    }
}

/**
 calls file picker window
 if a file is chosen calls myparseConFile
 */
-(IBAction)myImport:(id)sender
{
    NSOpenPanel* openPanel = [NSOpenPanel openPanel];
    
    openPanel.title = @"Choose a contour file";
    openPanel.showsResizeIndicator = YES;
    openPanel.showsHiddenFiles = NO;
    openPanel.canChooseDirectories = NO;
    openPanel.canCreateDirectories = YES;
    openPanel.allowsMultipleSelection = NO;
    
    [openPanel beginSheetModalForWindow:mrWindow completionHandler:^(NSInteger result) {
        if (result==NSOKButton) {
            
            NSURL *selection = openPanel.URLs[0];
            NSString* mypath = [selection.path stringByResolvingSymlinksInPath];
            
            NSLog(@"chosen path:%@",mypath);
            BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:mypath];
            if(fileExists)
                [self myparseConFile:mypath];
        }
        
    }];
    NSLog(@"Import button");
}

/**
 contour file parser
 @TODO parse contour files from old version
 @TODO get other information
 */
-(long) myparseConFile: (NSString*) mypath
{
    @try
    {
        NSFileHandle * fileHandle = [NSFileHandle fileHandleForReadingAtPath:mypath];
        NSString* input = [[NSString alloc] initWithData: [fileHandle availableData] encoding: NSUTF8StringEncoding];
        [input autorelease];
        NSArray* lines = [input componentsSeparatedByString: @"\n"];
        
        for (int iLine = 0; iLine < [lines count]; iLine++)
        {
            if ([[lines objectAtIndex:iLine] hasPrefix: @"[XYCONTOUR]"])
            {
                NSArray *components1 = [[lines objectAtIndex:iLine+1] componentsSeparatedByString:@" "];
                int iSlice = [viewerController maxMovieIndex]-[[components1 objectAtIndex:0] integerValue]-1;
                int iTime = [[components1 objectAtIndex:1] integerValue];
                int ROItype = [[components1 objectAtIndex:2] integerValue];
                int nPoints = [[lines objectAtIndex:iLine+2] integerValue];
                NSMutableArray  *points = [[NSMutableArray alloc] initWithCapacity:nPoints];
                
                for (int iPoint = 0; iPoint < nPoints; iPoint++)
                {
                    NSArray *components2 = [[lines objectAtIndex:iLine+3+iPoint] componentsSeparatedByString:@" "];
                    float x = [[components2 objectAtIndex:0] floatValue];
                    float y = [[components2 objectAtIndex:1] floatValue];
                    [points addObject: [viewerController newPoint: x : y]];
                }
                
                // my roi indexes are different from imported, so change them accordingly
                int myROINamesIDX;
                
                switch (ROItype){
                    case 0: myROINamesIDX = 1; break;
                    case 1: myROINamesIDX = 0; break;
                    case 2: myROINamesIDX = 2; break;
                    case 5: myROINamesIDX = 3; break;
                }
                
                NSMutableArray  *roiSeriesList  = [viewerController roiList: iSlice];
                NSMutableArray  *roiImageList = [roiSeriesList objectAtIndex: iTime];
                
                // check if given ROI exists. If so, delete it
                NSUInteger oldROIidx = [roiImageList indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
                    if ([[(ROI *)obj name] isEqualToString:myROINames[myROINamesIDX]]) {
                        *stop = YES;
                        return YES;
                    }
                    return NO;
                }];
                if (oldROIidx!=NSNotFound)
                    [viewerController deleteROI:[roiImageList objectAtIndex:oldROIidx]];
                
                ROI *newROI = [viewerController newROI:tCPolygon];
                newROI.points = points;
                [newROI setName: myROINames[myROINamesIDX]];
                [newROI setColor: myROIColors[myROINamesIDX]];
                
                [roiImageList addObject: newROI];
                
                NSLog(@"[XYCONTOUR] in line %d in Slice %d in Time %d ROI %d nPoints %d",iLine,iSlice,iTime,ROItype,nPoints);
            }
        }
        NSLog(@"Imported");
    }
    @catch (NSException * e)
    {
        NSLog(@"Problem loading file");
    }
}

- (void) openNewViewerKW
{
    BrowserController *currentBrowser = [BrowserController currentBrowser];
    NSArray         *selectedLines = [currentBrowser databaseSelection]; // all selected lines
    NSManagedObject    *selectedLine = [selectedLines objectAtIndex: 0]; // first line, dtudy or series
    NSArray            *loadList;
    NSArray            *cells = [[currentBrowser oMatrix] selectedCells]; // all sels
    NSMutableArray    *toOpenArray = [NSMutableArray array];
    
    NSLog(@"I am where I want to be");
    [[currentBrowser database] lock];
    int x = 0;
    if( [cells count] == 1 && [selectedLines count] > 1)    // Just one thumbnail is selected, but multiples lines are selected
    {
        for( NSManagedObject* curFile in selectedLines)
        {
            x++;
            loadList = nil;
            
            if( [[curFile valueForKey:@"type"] isEqualToString: @"Study"])
            {
                // Find the first series of images! DONT TAKE A ROI SERIES !
                if( [[curFile valueForKey:@"imageSeries"] count])
                {
                    curFile = [[curFile valueForKey:@"imageSeries"] objectAtIndex: 0];
                    loadList = [currentBrowser childrenArray: curFile];
                }
            }
            
            if( [[curFile valueForKey:@"type"] isEqualToString: @"Series"])
            {
                loadList = [currentBrowser childrenArray: curFile];
            }
            
            if( loadList) [toOpenArray addObject: loadList];
        }
    }
    else //open thumbnail
    {
        for( NSButtonCell *cell in cells)
        {
            x++;
            loadList = nil;
            
            if( [[currentBrowser matrixViewArray] count] > [cell tag])
            {
                NSManagedObject*  curFile = [[currentBrowser matrixViewArray] objectAtIndex: [cell tag]];
                
                if( [[curFile valueForKey:@"type"] isEqualToString: @"Image"]) loadList = [currentBrowser childrenArray: selectedLine onlyImages: YES];
                if( [[curFile valueForKey:@"type"] isEqualToString: @"Series"]) loadList = [currentBrowser childrenArray: curFile onlyImages: YES];
                
                if( loadList) [toOpenArray addObject: loadList];
            }
        }
    }
    
    [self processOpenViewerDICOMFromArrayKW: toOpenArray movie: YES viewer: nil];
    [[AppController sharedAppController] checkAllWindowsAreVisible: self makeKey: YES];
    
    [[currentBrowser database] unlock];
}


- (void) processOpenViewerDICOMFromArrayKW:(NSArray*) toOpenArray movie:(BOOL) movieViewer viewer: (ViewerController*) viewer
{
    long numberImages = 0;
    BOOL movieError = NO;
    BOOL tryToFlipData = NO;
    
    if( [toOpenArray count] == 1)    // Just one thumbnail is selected, check if multiples lines are selected
    {
        NSArray            *singleSeries = [toOpenArray objectAtIndex: 0];
        NSMutableArray    *splittedSeries = [NSMutableArray array];
        
        float interval=0;//, previousinterval = 0;
        
        [splittedSeries addObject: [NSMutableArray array]];
        
        if( [singleSeries count] > 1)
        {
            [[splittedSeries lastObject] addObject: [singleSeries objectAtIndex: 0]];
            
            // KW: here in the oryginal file, different processing is made depending on interval. This workes bad for cine images series from GE scanners. I simplified it.
            
            for( int x = 1; x < [singleSeries count]; x++)
            {
                interval = [[[singleSeries objectAtIndex: x -1] valueForKey:@"sliceLocation"] floatValue] - [[[singleSeries objectAtIndex: x] valueForKey:@"sliceLocation"] floatValue];
                //NSLog(@"interval: %f prev interval %f", interval,previousinterval);
                
                if(interval)
                    [splittedSeries addObject: [NSMutableArray array]];
                
                [[splittedSeries lastObject] addObject: [singleSeries objectAtIndex: x]];
            }
        }
        
        toOpenArray = splittedSeries;
    }
    
    if( [toOpenArray count] == 1)
    {
        NSRunCriticalAlertPanel( NSLocalizedString(@"4D Player",@"4D Player"), NSLocalizedString(@"To see an animated series, you have to select multiple series of the same area at different times: e.g. a cardiac CT", nil), NSLocalizedString(@"OK",nil), nil, nil);
        movieError = YES;
    }
    else if( [toOpenArray count] > MAX4D)
    {
        NSRunCriticalAlertPanel( NSLocalizedString(@"4D Player",@"4D Player"), NSLocalizedString(@"4D Player is limited to a maximum number of %d series.", nil), NSLocalizedString(@"OK",nil), nil, nil, MAX4D);
        movieError = YES;
    }
    else
    {
        numberImages = -1;
        
        for( unsigned long x = 0; x < [toOpenArray count]; x++)
        {
            if( numberImages == -1)
            {
                numberImages = [[toOpenArray objectAtIndex: x] count];
            }
            else if( [[toOpenArray objectAtIndex: x] count] != numberImages)
            {
                NSRunCriticalAlertPanel( NSLocalizedString(@"4D Player",@"4D Player"),  NSLocalizedString(@"In the current version, all series must contain the same number of images.",@"In the current version, all series must contain the same number of images."), NSLocalizedString(@"OK",nil), nil, nil);
                movieError = YES;
                x = [toOpenArray count];
            }
        }
    }
    if( movieError == NO && toOpenArray != nil)
        [[BrowserController currentBrowser] openViewerFromImages :toOpenArray movie: movieViewer viewer :viewer keyImagesOnly:NO tryToFlipData: tryToFlipData];
}

@end

