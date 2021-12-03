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
	runMacro("EnhancePuncta");
	rename("geph");
selectWindow("C2-image");
runMacro("EnhancePuncta");
	rename("psd");
run("Set Measurements...", "mean standard limit redirect=None decimal=2");

//threshold whole cell with whichever channel is best
selectWindow("fill");
		run("Gaussian Blur...", "sigma=1");
		rename("cell");
		/*run("Threshold...");
			waitForUser("select entire cell, press OK");
		run("Close");*/
		setAutoThreshold("Otsu dark");
		run("Convert to Mask", "method=Otsu background=Dark calculate");
	selectWindow("cell");
		run("Duplicate...", "duplicate");
			rename("t_cell");
				run("Divide...", "value=255");
				setMinAndMax(0, 0);

//determine psd95 threshold
imageCalculator("Multiply create stack", "psd","t_cell");
setThreshold(1, 65535);
run("Measure");
p_mean = getResult("Mean",0);
p_sd = getResult("StdDev",0);
p_th = p_mean + ((p_standarddev)*p_sd);
p_s_th = p_mean + ((p_shaftstandarddev)*p_sd);
selectWindow("Results");
run("Close");

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
				run("Dilate");
				

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
				run("Dilate");

//create actual shaft mask. Subtracting dilated "psd" mask (shaft1) from whole cell leaves just the shaft!
imageCalculator("Subtract create stack", "cell","p_shaft");
	rename("shaftPSD");
	imageCalculator("Subtract create stack", "shaftPSD","g_shaft");
	rename("shaft");
		run("Open");
		setOption("BlackBackground", false);
		run("Erode");
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
selectWindow("p_puncta");
run("Duplicate...", "duplicate");
rename("p_punctastack");

	selectWindow("p_puncta");
	run("Set Measurements...", "area centroid redirect=None decimal=2");
	run("Analyze Particles...", "size=2-Infinity pixel show=Outlines display add");

	PSDlength = nResults;
	objectarea = newArray(getResult("Area",0), getResult("Area",1));
	for (j=2; j<nResults; j++) {
		objectarea = Array.concat(objectarea, getResult("Area",j));
	}
	xcentroids = newArray(getResult("X",0), getResult("X",1));
	for (j=2; j<nResults; j++) {
		xcentroids = Array.concat(xcentroids, getResult("X",j));
	}
	ycentroids = newArray(getResult("Y",0), getResult("Y",1));
	for (j=2; j<nResults; j++) {
		ycentroids = Array.concat(ycentroids, getResult("Y",j));
	}
				run("Clear Results");
		run("Set Measurements...", "area mean redirect=None decimal=2");
		selectWindow("psd");
			roiManager("multi-measure measure_all");
	//an array of camkii values that is the average intensity within the object divided by the mean intensity of camkii in the shaft (intensity/num pixels)
	
	PSDintensity = newArray(
		getResult("Mean",0)/(p_shaftvalues),
		getResult("Mean",1)/(p_shaftvalues));
	for (j=2; j<PSDlength; j++) {
		PSDintensity = Array.concat(PSDintensity,
			getResult("Mean",j)/(p_shaftvalues));
	}
		run("Clear Results");


	run("Clear Results");
	selectWindow("ROI Manager");
	roiManager("Save", path+name+"RoiSetPSD.zip");
	run("Close");

selectWindow("g_puncta");
run("Duplicate...", "duplicate");
rename("g_punctastack");

	selectWindow("g_puncta");
	run("Set Measurements...", "area centroid redirect=None decimal=2");
	run("Analyze Particles...", "size=2-Infinity pixel show=Outlines display add");

	gephlength = nResults;
	gephobjectarea = newArray(getResult("Area",0), getResult("Area",1));
	for (j=2; j<nResults; j++) {
		gephobjectarea = Array.concat(gephobjectarea, getResult("Area",j));
	}
	gephxcentroids = newArray(getResult("X",0), getResult("X",1));
	for (j=2; j<nResults; j++) {
		gephxcentroids = Array.concat(gephxcentroids, getResult("X",j));
	}
	gephycentroids = newArray(getResult("Y",0), getResult("Y",1));
	for (j=2; j<nResults; j++) {
		gephycentroids = Array.concat(gephycentroids, getResult("Y",j));
	}
				run("Clear Results");
		run("Set Measurements...", "area mean redirect=None decimal=2");
		selectWindow("geph");
			roiManager("multi-measure measure_all");
	//an array of camkii values that is the average intensity within the object divided by the mean intensity of camkii in the shaft (intensity/num pixels)
	
	gephPSD = newArray(
		getResult("Mean",0)/(g_shaftvalues),
		getResult("Mean",1)/(g_shaftvalues));
	for (j=2; j<gephlength; j++) {
		gephPSD = Array.concat(gephPSD,
			getResult("Mean",j)/(g_shaftvalues));
	}
		run("Clear Results");


	run("Clear Results");
	selectWindow("ROI Manager");
	roiManager("Save", path+name+"RoiSetGeph.zip");
	run("Close");

	
	minz = newArray(9999,9999);
	for(j=0; j<PSDlength; j++) {
		Zei = newArray(9999,9999);
		Ex = xcentroids[j];
		Ey = ycentroids[j];
	
		for (k=0; k<gephlength; k++) {
			Ix = gephxcentroids[k];
			Iy = gephycentroids[k];
				z =(sqrt( ((Ex-Ix)*(Ex-Ix)) + ((Ey-Iy)*(Ey-Iy))));
					Zei = Array.concat(Zei, z );
			}
	rank = Array.rankPositions(Zei);
	minz = Array.concat(minz, Zei[rank[0]]);
	
	}
	minz = Array.deleteIndex(minz, 0);
	minz = Array.deleteIndex(minz, 0);	
	run("Clear Results");

//psd proximity to geph
	g_minz = newArray(9999,9999);
	for (k=0; k<gephlength; k++) {
			Zei = newArray(9999,9999);
			Ix = gephxcentroids[k];
			Iy = gephycentroids[k];
			
		for(j=0; j<PSDlength; j++) {
			Ex = xcentroids[j];
			Ey = ycentroids[j];
				z =(sqrt( ((Ex-Ix)*(Ex-Ix)) + ((Ey-Iy)*(Ey-Iy))));
					Zei = Array.concat(Zei, z );
			}
	rank = Array.rankPositions(Zei);
	g_minz = Array.concat(g_minz, Zei[rank[0]]);
	
	}
	g_minz = Array.deleteIndex(g_minz, 0);
	g_minz = Array.deleteIndex(g_minz, 0);
	Array.show("Spine/shaft ratios",minz,PSDintensity,objectarea,g_minz,gephPSD,gephobjectarea);

selectWindow("Results");
run("Close");
run("Close All");

