// Day / night transition curves. Softened to match the wider transition
// windows used by other shaders — the legacy code transitioned
// `moonVisibility` over ~5.7° of celestial movement (MdotU = -0.1 → 0) and
// then snapped, which caused (a) the sun-to-moon light-color flip to happen
// in a few frames, (b) celestial shadows to start/stop at very different
// times than other shaders. The new curves use smoothstep over a wider band
// so sunset/sunrise lingers and moonlight ramps in alongside the dying sun.

float sunUp  = dot(sunVector,  upVector);  //  +1 = sun at zenith,  -1 = nadir
float moonUp = dot(moonVector, upVector);

// Sun activity: 0 well below horizon, 1 well above. Some shaders use (-0.1, 0.5);
// the wider second arg lets the sunlit term keep its warm colour longer past
// the geometric sunset (atmospheric scattering does the rest of the visuals).
float sunActivity  = smoothstep(-0.1, 0.16, sunUp);

// Moon activity: same pattern, mirrored. The narrower upper bound (0.10) lets
// moonlight reach its full strength once the moon is even modestly above the
// horizon, matching how other packs front-load nighttime ambient.
float moonActivity = smoothstep(-0.1, 0.10, moonUp);

// Sun colour: warm-amber sunset → near-white golden noon, gated by activity so the
// sun term cleanly fades out (no abrupt cutoff) as the sun sinks below the
// horizon.
// Adjusted daytime tint (sunUp > 0) to be warmer and more golden (1.0, 0.95, 0.9) 
// instead of the original cooler (1.0, 1.0, 1.1).
vec3 sunColorBase  = mix(vec3(1.0, 0.65, 0.35) * 0.15, vec3(1.0, 0.95, 0.9), max(sunUp, 0.0));
vec3 sunColor      = sunColorBase * sunActivity;

// Moon colour: cool blue, scaled to ~0.02 of sun illuminance (matches the
// MOON_ILLUMINANCE constant used by the atmosphere LUT).
vec3 moonColorBase = vec3(0.65, 0.85, 1.0) * 0.02;
vec3 moonColor     = moonColorBase * moonActivity;

// Direct light colour drives shadow tinting and direct-sun lighting downstream.
// During twilight both sun and moon may contribute partially — this matches
// reference packs where shadows soften and shift colour through dusk.
lightColor = sunColor + moonColor;

// Ambient (sky-tint) intensity. The Hillaire LUT already encodes time-of-day
// in colour, so this scalar is mostly a dim-down-at-night knob. Smooth blend
// so dawn/dusk darken gradually instead of snapping.
float dayScale   = mix(0.1, 1.0, max(sunUp, 0.0));
float nightScale = 0.025;
float ambientScale = mix(nightScale, dayScale, sunActivity);

// Neutral sky-tint ambient. (Removed the old sunsetMask warm injection — a
// hardcoded orange peaking near the horizon (sunUp≈0.08) that double-dipped on
// the warmth the Hillaire atmosphere LUT already encodes.)
vec3 baseAmbient = vec3(0.27, 0.32, 0.38);
ambientColor = baseAmbient * ambientScale;
