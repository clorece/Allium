#define CURRENT_DAY 1 // [0 1 2 3 4 5 6 7]
/* clouds:
    0 - auto
    1 - normal
    2 - partly cloudy
    3 - clear w/ cirrus
    4 - clear no cirrus
    5 - cloudy no cirrus
    6 - mostly cloudy
    7 - overcast
*/
float dailyCoverage, cirrusAmount;

void getWeatherForDay(int day, out float coverage, out float cirrus) {
    if (day == 1) {
        // partly cloudy
        coverage = 0.65;
        cirrus = 0.75;
    } else if (day == 2) {
        // clear w/ cirrus
        coverage = 0.0;
        cirrus = 1.0;
    } else if (day == 3) {
        // clear no cirrus
        coverage = 0.0;
        cirrus = 0.0;
    } else if (day == 4) {
        // cloudy no cirrus
        coverage = 1.0;
        cirrus = 0.0;
    } else if (day == 5) {
        // mostly cloudy
        coverage = 1.5;
        cirrus = 0.0;
    } else if (day == 6) {
        // overcast
        coverage = 2.0;
        cirrus = 0.0;
    } else {
        // day 0 - normal
        coverage = 1.0;
        cirrus = 1.0;
    }
}

void dayWeatherCycle() {
    #if CURRENT_DAY == 0
        // ------------------------ day cycle with transitions ------------------------ //
        int currentDay = worldDay % 7;
        int nextDay = (worldDay + 1) % 7;
        float dayProgress = fract(worldDay);
        
        // Apply easing for smoother transitions (optional)
        float t = smoothstep(0.0, 1.0, dayProgress);
        
        float currentCoverage, currentCirrus;
        float nextCoverage, nextCirrus;
        
        getWeatherForDay(currentDay, currentCoverage, currentCirrus);
        getWeatherForDay(nextDay, nextCoverage, nextCirrus);
        
        // Interpolate between current and next day
        dailyCoverage = mix(currentCoverage, nextCoverage, t);
        cirrusAmount = mix(currentCirrus, nextCirrus, t);
        
    #elif CURRENT_DAY == 1
        // ------------------------ day 1 (normal) ------------------------ //
        dailyCoverage = 1.0;
        cirrusAmount = 1.0;
    #elif CURRENT_DAY == 2
        // ------------------------ day 2 (partly cloudy) ------------------------ //
        dailyCoverage = 0.65;
        cirrusAmount = 0.75;
    #endif
}