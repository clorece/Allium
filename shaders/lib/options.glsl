#define SHADOW_FILTER
#define DITHER_FILTER

#define SHADOW_RESOLUTION 4096 //[512 1024 1563 2048 3072 4096 6144 8192]
#define SHADOW_FILTER_QUALITY 4 //[1 2 3 4 6 8 10 12 14 16 18 20 22 24]
#define SHADOW_MAP_BIAS 0.85 //Increase this if you get shadow acne. Decrease this if you get peter panning. [0.000 0.001 0.002 0.003 0.004 0.005 0.006 0.007 0.008 0.009 0.010 0.012 0.014 0.016 0.018 0.020 0.022 0.024 0.026 0.028 0.030 0.035 0.040 0.045 0.050]

//#define FAKE_SSS  // WIP
#define SCATTER_AMOUNT 2.0; // [1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0]

//#define VOLUMETRIC_LIGHT
#define VL_STEPS 2 // [1 2 3 4]
#define VL_INTENSITY 0.3 // [0.1 0.15 0.2 0.25 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]


//#define TAA
#define TAA_JITTER_AMOUNT 2.0
#define TAA_JITTER_SPREAD 1.0

#define BLOOM

//#define WIND_MOVEMENT // WIP