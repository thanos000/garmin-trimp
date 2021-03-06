using Toybox.WatchUi as Ui;

class TrimpView extends Ui.SimpleDataField {

	//conf
	const movingThreshold = 1.0;

	var userRestHR = 0;
	var genderMultiplier = 1.92;
	var userMaxHR=0;
	var staticSport = true;
	
	var latestTime = 0;
	var latestHR = 0;
	var latestDistance = 0;
	
	var movingTime = 0.0;
	
	//custom fit fields
	var trimp = 0.0;
	var trimpChartField;
	var trimpSummaryField;
	var trimpPerHourSummaryField;
	
	//lifecycle
	var running = false;

    //! Set the label of the data field here.
    function initialize() {
        SimpleDataField.initialize();
        label = "TRIMP";
                
        //use custom HR values if possible
        var customHREnabled = calcNullable(Application.getApp().getProperty("customHR"), false);
        var customRestHR = calcNullable(Application.getApp().getProperty("restHR"),0);
        var customMaxHR = calcNullable(Application.getApp().getProperty("maxHR"),0);
        
        System.println(customHREnabled);
        System.println(customRestHR);
        System.println(customMaxHR);
        
        if(customHREnabled && customRestHR != null && customMaxHR != null && customRestHR > 0 && customMaxHR > customRestHR){
        	System.println("using custom HR");
        	userRestHR = customRestHR;
        	userMaxHR = customMaxHR;
        	
        } else { //use hr data from profile
        	var zones = UserProfile.getHeartRateZones(UserProfile.getCurrentSport());
        	userMaxHR = calcNullable(zones[zones.size()-1],0);
        
        	userRestHR = calcNullable(UserProfile.getProfile().restingHeartRate,0);
        	
        	System.println("using profile HR");
        	System.println(userRestHR + "/" + userMaxHR);
        }
        
        
        genderMultiplier = UserProfile.getProfile().gender == UserProfile.GENDER_MALE?1.92:1.67;     
                
        staticSport = UserProfile.getCurrentSport() == UserProfile.HR_ZONE_SPORT_GENERIC;
        
        //Create fit contributions
        trimpChartField = createField("Trimp", 0, FitContributor.DATA_TYPE_FLOAT, { :mesgType=>FitContributor.MESG_TYPE_RECORD});
        trimpSummaryField = createField("Trimp", 1, FitContributor.DATA_TYPE_FLOAT, { :mesgType=>FitContributor.MESG_TYPE_SESSION});
        trimpPerHourSummaryField = createField("Trimp/Hr", 2, FitContributor.DATA_TYPE_FLOAT, { :mesgType=>FitContributor.MESG_TYPE_SESSION});
        
        resetData();
                
        //Me
        /*genderMultiplier = 1.92;
        userRestHR = 45;
        userMaxHR = 175;*/
    }

    //! The given info object contains all the current workout
    //! information. Calculate a value and return it in this method.
    function compute(info) {
    	var time = calcNullable(info.elapsedTime, 0);
    	var heartRate = calcNullable(info.currentHeartRate, 0);
    	var timeVariation = (time - latestTime); //Minutes
    	var distance = calcNullable(info.elapsedDistance, 0);
    	   	
    	//prevent wrong value when user min/max HR is not available
    	if(userRestHR <=0 || userMaxHR <= 0 || userRestHR == userMaxHR){
    		return "!min/max HR";
    	}
    	
    	
    	//prevent wrong values when no HR is available
		//Check for Trimp value in case of a short signal loss during the ride
		if(running && heartRate == 0 && trimp == 0){
			return "No HR";
		}
		
		//prevent negative TRIMP with HR lower than user's rest HR
		if(heartRate < userRestHR){
			heartRate = userRestHR;
		}
    
    	//convert ms to minutes at display to reduce roundings influence
    	//use average speed since last measure in m/s
    	//ony update if moving (according to sport) and activity not paused / stopped 
    	if(running && (staticSport || (timeVariation > 0 && (distance-latestDistance)/(timeVariation/1000.0) > movingThreshold))){
    		trimp += timeVariation * getHeartRateReserve(heartRate) * 0.64 * Math.pow(Math.E, getExp(heartRate));
    		movingTime += timeVariation;
    		
    		//update .fit data
	    	trimpChartField.setData(trimp/60000.0);
	    	trimpSummaryField.setData(trimp/60000.0);
	    	
	    	if (movingTime > 0) {
	            var movingTimeHr = movingTime / 60.0;
	            trimpPerHourSummaryField.setData(trimp/movingTimeHr);
	        }
    	}
        
    	//update latest data
    	latestTime = time;
    	latestHR = heartRate;
    	latestDistance = distance;
    
    	return (trimp/60000.0).toLong();
    }
    
    //manage activity lifecycle
    function onTimerStart(){
    	running = true;
    }
    
    function onTimerPause(){
    	running = false;
    }
    
    function onTimerResume(){
    	running = true;
    }
    
    function onTimerStop(){
    	running = false;
    }
    
    function onTimerReset(){
	    resetData();
    }
    
    function resetData(){
    	latestTime = 0;
		latestHR = 0;
		latestDistance = 0;
		movingTime = 0.0;
		trimp = 0.0;
		
		trimpChartField.setData(0);
	    trimpSummaryField.setData(0);
	    trimpPerHourSummaryField.setData(0);
    }
    
    function getHeartRateReserve(heartRate){
    	if(userMaxHR != userRestHR){
    		var latestHRAverage = (heartRate + latestHR) / 2.0;
    		return 1.0*(latestHRAverage - userRestHR)/(userMaxHR - userRestHR);
    	}
    	return 0;
    }
    
    function getExp(heartRate){
    	return genderMultiplier * getHeartRateReserve(heartRate);
    }
    
    function calcNullable(nullableValue, defaultValue) {
	   if (nullableValue != null) {
	   	return nullableValue;
	   } else {
	   	return defaultValue;
   	   }	
	}

}