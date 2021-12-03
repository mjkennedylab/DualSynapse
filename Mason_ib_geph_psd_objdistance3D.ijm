//--- set the image pixel size here-----
xpxsize= 0.114; //x-y pixel size in microns
zpxsize = 0.4; //z pixel size in microns

//scaling factors and variables: th and s-th for example
p_standarddev = 2;
p_shaftstandarddev = 1;
g_standarddev = 2;
g_shaftstandarddev = 1;

// Imaging analysis program
run("Close All");
if (isOpen("ROI Manager")) {
     selectWindow("ROI Manager");
     run("Close");
  }
   if (isOpen("Results")) {
     selectWindow("Results");
     run("Close");
  }

open();
path = getDirectory("image");
name = File.nameWithoutExtension;
rename("image");

waitForUser("Select a region of dendrite then crop. press OK");
run("Subtract Background...", "rolling=50 stack");
// Split the colors, smooth and rename them
run("Split Channels");
selectWindow("C3-image");
	rename("fill");
selectWindow("C1-image");
	runMacro("EnhancePuncta3D");
	rename("geph");
selectWindow("C2-image");
runMacro("EnhancePuncta3D");
	rename("psd");
run("Set Measurements...", "mean standard limit redirect=None decimal=2");

//threshold whole cell with whichever channel is best
selectWindow("fill");
run("Gaussian Blur 3D...", "x=2 y=2 z=1");
rename("cell");
run("Duplicate...", "duplicate");'
rename("cellfillmask");
//run("Enhance Contrast", "saturated=0.1");
setAutoThreshold("Triangle dark");
run("Convert to Mask", "method=Triangle background=Dark");
run("Dilate (3D)", "iso=255");
run("Dilate (3D)", "iso=255");
run("Dilate (3D)", "iso=255");
run("Dilate (3D)", "iso=255");
run("Dilate (3D)", "iso=255");
run("Close-", "stack");

selectWindow("cell");
setAutoThreshold("Otsu dark");
		/*run("Threshold...");
			waitForUser("select entire cell, press OK");
		run("Close");*/
		setAutoThreshold("Otsu dark");
		run("Convert to Mask", "method=Otsu background=Dark calculate");
	selectWindow("cell");
		run("Duplicate...", "duplicate");
			rename("t_cell");
				run("Divide...", "value=255 stack"); // for 3d
				run("16-bit"); // for 3d
				setMinAndMax(0, 0);


//determine psd95 threshold
imageCalculator("Multiply create stack", "psd","t_cell"); // for 3d
setThreshold(1, 65535);
run("Measure");
p_mean = getResult("Mean",0);
p_sd = getResult("StdDev",0);
p_th = p_mean + ((p_standarddev)*p_sd);
p_s_th = p_mean + ((p_shaftstandarddev)*p_sd);
selectWindow("Results");
run("Close");


print(p_mean);
print(p_sd);
print(p_th);

//CreateImagesforPSDThreshold
selectWindow("psd");
	run("Duplicate...", "duplicate");
		rename("p_puncta");
			run("Duplicate...", "duplicate");
				rename("p_shaft");
selectWindow("p_puncta");
//run("Threshold...");
	setAutoThreshold("Default dark no-reset");
		setThreshold(p_th, 65535);
			setOption("BlackBackground", false);
			run("Convert to Mask", "method=Default background=Dark");	
selectWindow("p_shaft");
	setAutoThreshold("Default dark no-reset");
//run("Threshold...");
		setThreshold(p_s_th, 65535);
			setOption("BlackBackground", false);
			run("Convert to Mask", "method=Default background=Dark");
				//run("Dilate");
				run("Dilate (3D)", "iso=255");

//determine geph threshold
imageCalculator("Multiply create stack", "geph","t_cell");
setThreshold(1, 65535);
run("Measure");
g_mean = getResult("Mean",0);
g_sd = getResult("StdDev",0);
g_th = g_mean + ((g_standarddev)*g_sd);
g_s_th = g_mean + ((g_shaftstandarddev)*g_sd);
selectWindow("Results");
run("Close");

//CreateImagesforGephThreshold
selectWindow("geph");
	run("Duplicate...", "duplicate");
		rename("g_puncta");
			run("Duplicate...", "duplicate");
				rename("g_shaft");
selectWindow("g_puncta");
//run("Threshold...");
	setAutoThreshold("Default dark no-reset");
		setThreshold(g_th, 65535);
			setOption("BlackBackground", false);
			run("Convert to Mask", "method=Default background=Dark");		
selectWindow("g_shaft");
	setAutoThreshold("Default dark no-reset");
//run("Threshold...");
		setThreshold(g_s_th, 65535);
			setOption("BlackBackground", false);
			run("Convert to Mask", "method=Default background=Dark");
				//run("Dilate");
				run("Dilate (3D)", "iso=255");

//create actual shaft mask. Subtracting dilated "psd" mask (shaft1) from whole cell leaves just the shaft!
imageCalculator("Subtract create stack", "cell","p_shaft");
	rename("shaftPSD");
	imageCalculator("Subtract create stack", "shaftPSD","g_shaft");
	rename("shaft");
		run("Open","stack");
		setOption("BlackBackground", false);
		run("Erode","stack");
		run("Divide...", "value=255 stack");
		setMinAndMax(0, 0);

selectWindow("shaft");
run("Duplicate...", "title=ShaftStack duplicate");
//here we go! this is the analysis stage. Now we can measure actual images with thesholded objects to measure average intensity values within objects
run("Clear Results");

//Overlay the shaft threshold onto the geph channel
imageCalculator("Multiply create stack", "psd","shaft");

// Measure sum of all pixel intensities from p_shaft mask of color of interest
run("Set Measurements...", "mean limit redirect=None decimal=2");
	selectWindow("Result of psd");
		setThreshold(1, 65535);
		run("Measure");

//Overlay the shaft threshold onto the geph channel
imageCalculator("Multiply create stack", "geph","shaft");

// Measure sum of all pixel intensities from p_shaft mask of color of interest
run("Set Measurements...", "mean limit redirect=None decimal=2");
	selectWindow("Result of geph");
		setThreshold(1, 65535);
		run("Measure");


// measurements here are the number of pixels from each shaft mask. This is the area.

//turning shaft values into an array for computation
p_shaftvalues = getResult("Mean",0);
g_shaftvalues = getResult("Mean",1);

run("Clear Results");
	
//Now is when we take the average intensity of CaMKII within each PSD object. The data that results will be 1) the area of each object and the centroid coordinates, and 2) the average CaMKII intensity within each object.
//This program will cycle through the timepoints until no timepoints remain

//-------PSD
selectWindow("p_puncta");
run("Duplicate...", "duplicate");
rename("p_punctastack");

selectWindow("p_puncta");
// only include PSD95 puncta within cell fill mask here
imageCalculator("Multiply create stack", "p_puncta","cellfillmask");

// for 3D calculation of Centroid and Volume
run("3D Manager Options", "volume centroid_(unit) centre_of_mass_(pix) centre_of_mass_(unit) distance_between_centers=10 distance_max_contact=1.80 drawing=Contour");
run("3D Simple Segmentation", "low_threshold=1 min_size=4 max_size=-1");
run("3D Centroid");	
saveAs("Results",path+name+"_PSDcentroid.csv");
IJ.renameResults("PSD centroid");
run("3D Geometrical Measure");
IJ.renameResults("PSD Volume");
 	
	//run("Set Measurements...", "area centroid redirect=None decimal=2");
	//run("Analyze Particles...", "size=2-Infinity pixel show=Outlines display add");
	selectWindow("PSD Volume");
	PSDlength = Table.size();
	volstr="Volume(pix)";
	objectvol = newArray(getResult(volstr,0), getResult(volstr,1));
	for (j=2; j<PSDlength; j++) {
		objectvol = Array.concat(objectvol, getResult(volstr,j));
	}
	selectWindow("PSD centroid");
	cxstr = "CX(pix)";
	cystr = "CY(unit)";
	czstr = "CZ(pix)";
	xcentroids = newArray(getResult(cxstr,0), getResult(cxstr,1));
	for (j=2; j<PSDlength; j++) {
		xcentroids = Array.concat(xcentroids, getResult(cxstr,j));
	}
	ycentroids = newArray(getResult(cystr,0), getResult(cystr,1));
	for (j=2; j<PSDlength; j++) {
		ycentroids = Array.concat(ycentroids, getResult(cystr,j));
	}
	zcentroids = newArray(getResult(czstr,0), getResult(czstr,1));
	for (j=2; j<PSDlength; j++) {
		zcentroids = Array.concat(zcentroids, getResult(czstr,j));
	}

//Array.show("Results",objectvol,xcentroids,ycentroids,zcentroids); //check that these vals are correct with this
	
run("Clear Results");

		//run("Set Measurements...", "area mean redirect=None decimal=2");
		//selectWindow("psd");
		//	roiManager("multi-measure measure_all");
run("3D Intensity Measure", "objects=Seg signal=psd");
IJ.renameResults("PSD Mean Intensity");
	//an array of camkii values that is the average intensity within the object divided by the mean intensity of camkii in the shaft (intensity/num pixels)

	psdmeanstr = "Average";
	PSDintensity = newArray(
		getResult(psdmeanstr,0)/(p_shaftvalues),
		getResult(psdmeanstr,1)/(p_shaftvalues));
	for (j=2; j<PSDlength; j++) {
		PSDintensity = Array.concat(PSDintensity,
			getResult(psdmeanstr,j)/(p_shaftvalues));
	}
run("Clear Results");
run("Clear Results");

selectWindow("Seg");
save(path+name+"3DRoisPSD.tiff");
rename("PSD3DPuncta");
print("Finished Saving ROIs");

close("PSD Volume");
close("PSD centroid");
close("PSD Mean Intensity");
close("Bin");
close("Seg");

// now Gephyrin-----------------

selectWindow("g_puncta");
run("Duplicate...", "duplicate");
rename("g_punctastack");
selectWindow("g_puncta");
// only include geph puncta within cell fill mask here
imageCalculator("Multiply create stack", "g_puncta","cellfillmask");

run("3D Manager Options", "volume centroid_(unit) centre_of_mass_(pix) centre_of_mass_(unit) distance_between_centers=10 distance_max_contact=1.80 drawing=Contour");
run("3D Simple Segmentation", "low_threshold=1 min_size=4 max_size=-1");
run("3D Centroid");
saveAs("Results",path+name+"_Gephcentroid.csv");
IJ.renameResults("Geph centroid");	
run("3D Geometrical Measure");
IJ.renameResults("Geph Volume");
	
	//run("Set Measurements...", "area centroid redirect=None decimal=2");
	//run("Analyze Particles...", "size=2-Infinity pixel show=Outlines display add");
selectWindow("Geph Volume");
	gephlength = Table.size();
	volstr="Volume(pix)";
	gephobjectvol = newArray(getResult(volstr,0), getResult(volstr,1));
	for (j=2; j<gephlength; j++) {
		gephobjectvol = Array.concat(gephobjectvol, getResult(volstr,j));
	}
	selectWindow("Geph centroid");
	cxstr = "CX(pix)";
	cystr = "CY(unit)";
	czstr = "CZ(pix)";
	gephxcentroids = newArray(getResult(cxstr,0), getResult(cxstr,1));
	for (j=2; j<gephlength; j++) {
		gephxcentroids = Array.concat(gephxcentroids, getResult(cxstr,j));
	}
	gephycentroids = newArray(getResult(cystr,0), getResult(cystr,1));
	for (j=2; j<gephlength; j++) {
		gephycentroids = Array.concat(gephycentroids, getResult(cystr,j));
	}
	gephzcentroids = newArray(getResult(czstr,0), getResult(czstr,1));
	for (j=2; j<gephlength; j++) {
		gephzcentroids = Array.concat(gephzcentroids, getResult(czstr,j));
	}
				run("Clear Results");
		//run("Set Measurements...", "area mean redirect=None decimal=2");
		
		selectWindow("geph");
			//roiManager("multi-measure measure_all");
			run("3D Intensity Measure", "objects=Seg signal=geph");
IJ.renameResults("Geph Mean Intensity");
	//an array of camkii values that is the average intensity within the object divided by the mean intensity of camkii in the shaft (intensity/num pixels)
		gephmeanstr = "Average";
	gephPSDintensity = newArray(
		getResult(gephmeanstr,0)/(g_shaftvalues),
		getResult(gephmeanstr,1)/(g_shaftvalues));
	for (j=2; j<gephlength; j++) {
		gephPSDintensity = Array.concat(gephPSDintensity,
			getResult(gephmeanstr,j)/(g_shaftvalues));
	}
		run("Clear Results");
	run("Clear Results");

selectWindow("Seg");
save(path+name+"3DRoisGeph.tiff");
rename("Gephyrin3DPuncta");
print("Finished Saving ROIs");

print("all done with this part");


close("Geph Volume");
close("Geph centroid");
close("Geph Mean Intensity");
close("Bin");


run("Merge Channels...", "c1=PSD3DPuncta c2=Gephyrin3DPuncta create keep ignore");
rename("PSDGephOverlay");
save(path+name+"_PSDGephPuncta.tiff");

	
	minz = newArray(9999,9999);
	minz_um = newArray(9999,9999);
	for(j=0; j<PSDlength; j++) {
		Zei = newArray(9999,9999);
		Zei_um = newArray(9999,9999);
		Ex = xcentroids[j];
		Ey = ycentroids[j];
		Ez = zcentroids[j];
		for (k=0; k<gephlength; k++) {
			Ix = gephxcentroids[k];
			Iy = gephycentroids[k];
			Iz = gephzcentroids[k];
				z =(sqrt( ((Ex-Ix)*(Ex-Ix)) + ((Ey-Iy)*(Ey-Iy)) + ((Ez-Iz)*(Ez-Iz)) ));
					Zei = Array.concat(Zei, z );
				z_um =sqrt( pow((Ex-Ix)*xpxsize,2) + pow((Ey-Iy)*xpxsize,2) + pow((Ez-Iz)*zpxsize,2) );
				Zei_um = Array.concat(Zei_um,z_um);
			}
	rank = Array.rankPositions(Zei);
	minz = Array.concat(minz, Zei[rank[0]]);
	rank_um = Array.rankPositions(Zei_um);
	minz_um = Array.concat(minz_um, Zei_um[rank_um[0]]);
	}
	minz = Array.deleteIndex(minz, 0);
	minz = Array.deleteIndex(minz, 0);	
	minz_um = Array.deleteIndex(minz_um, 0);
	minz_um = Array.deleteIndex(minz_um, 0);
	run("Clear Results");

//psd proximity to geph
	g_minz = newArray(9999,9999);
	g_minz_um = newArray(9999,9999);
	for (k=0; k<gephlength; k++) {
			Zei = newArray(9999,9999);
			Zei_um = newArray(9999,9999);
			Ix = gephxcentroids[k];
			Iy = gephycentroids[k];
			Iz = gephzcentroids[k];
		for(j=0; j<PSDlength; j++) {
			Ex = xcentroids[j];
			Ey = ycentroids[j];
			Ez = zcentroids[j];
				z =(sqrt( ((Ex-Ix)*(Ex-Ix)) + ((Ey-Iy)*(Ey-Iy)) + ((Ez-Iz)*(Ez-Iz)) ));
				Zei = Array.concat(Zei, z );
				z_um =sqrt( pow((Ex-Ix)*xpxsize,2) + pow((Ey-Iy)*xpxsize,2) + pow((Ez-Iz)*zpxsize,2) );
				Zei_um = Array.concat(Zei_um,z_um);
			}
	rank = Array.rankPositions(Zei);
	g_minz = Array.concat(g_minz, Zei[rank[0]]);
	rank_um = Array.rankPositions(Zei_um);
	g_minz_um = Array.concat(g_minz_um, Zei_um[rank_um[0]]);
	
	}
	g_minz = Array.deleteIndex(g_minz, 0);
	g_minz = Array.deleteIndex(g_minz, 0);
	g_minz_um = Array.deleteIndex(g_minz_um, 0);
	g_minz_um = Array.deleteIndex(g_minz_um, 0);
	Array.show("Spine/shaft ratios",minz,minz_um,PSDintensity,objectvol,g_minz,g_minz_um,gephPSDintensity,gephobjectvol);

saveAs("Results",path+name+"SpineShaftRatios.csv");
run("Close");
run("Close All");

