#ifndef BLOCKLIGHT_COLORS_GLSL
#define BLOCKLIGHT_COLORS_GLSL

// Blocklight colors for special light-emitting blocks, pre-rewrite of Serie

#ifndef XLIGHT_R
#define XLIGHT_R 1.0
#endif
#ifndef XLIGHT_G
#define XLIGHT_G 1.0
#endif
#ifndef XLIGHT_B
#define XLIGHT_B 1.0
#endif

#ifndef GLOWING_LICHEN
#define GLOWING_LICHEN 0
#endif


float GetLuminance(vec3 color) {
    return dot(color, vec3(0.299, 0.587, 0.114));
}

float pow2(float x) {
    return x * x;
}
vec3 pow2(vec3 x) {
    return x * x;
}

vec3 blocklightCol = vec3(1.7, 0.9, 0.4) * 0.075 * vec3(XLIGHT_R, XLIGHT_G, XLIGHT_B);
	
void AddSpecialLightDetail(inout vec3 light, vec3 albedo, float emission) {
	vec3 lightM = max(light, vec3(0.0));
	lightM /= (0.2 + 0.8 * GetLuminance(lightM));
	lightM *= (1.0 / (1.0 + emission)) * 0.22;
	light *= 0.9;
	light += pow2(lightM / (albedo + 0.1));
}

vec3 fireSpecialLightColor = vec3(1.7, 0.6, 0.2) * 3.8;
vec3 lavaSpecialLightColor = vec3(3.0, 0.9, 0.2) * 4.0;

vec3 netherPortalSpecialLightColor = vec3(1.8, 0.4, 2.2) * 0.8;
vec3 redstoneSpecialLightColor = vec3(4.0, 0.1, 0.1);
vec4 soulFireSpecialColor = vec4(vec3(0.3, 2.0, 2.2) * 1.0, 0.3);
float candleColorMult = 2.0;
float candleExtraLight = 0.004;
vec4 GetSpecialBlocklightColor(int mat) {
	if (mat < 50) {
		if (mat < 26) {
			if (mat < 14) {
				if (mat < 8) {
					//#if COLORED_LIGHTING == 0 && GLOBAL_ILLUMINATION == 2
					//	if (mat == 2) return vec4(vec3(3.05, 0.33, 0.17), 0.0); // Torch
					//#else
						if (mat == 2) return vec4(fireSpecialLightColor * 1.5, 0.0); // Torch
					//#endif
					#ifndef END
						if (mat == 3) return vec4(vec3(1.0, 1.0, 1.0) * 4.0, 0.0); // End Rod - This is the base for all lights. Total value 12
					#else
						if (mat == 3) return vec4(vec3(1.25, 0.5, 1.25) * 4.0, 0.0); // End Rod in the End dimension
					#endif
					if (mat == 4) return vec4(vec3(0.7, 1.5, 2.0) * 3.0, 0.0); // Beacon
					if (mat == 5) return vec4(fireSpecialLightColor, 0.0); // Fire
					if (mat == 6) return vec4(vec3(0.7, 1.5, 1.5) * 1.7, 0.0); // Sea Pickle:Waterlogged
					if (mat == 7) return vec4(vec3(1.1, 0.85, 0.35) * 5.0, 0.0); // Ochre Froglight
				} else {
					if (mat == 8) return vec4(vec3(0.6, 1.3, 0.6) * 4.5, 0.0); // Verdant Froglight
					if (mat == 9) return vec4(vec3(1.1, 0.5, 0.9) * 4.5, 0.0); // Pearlescent Froglight
					if (mat == 10) return vec4(vec3(1.7, 0.9, 0.4) * 4.0, 0.0); // Glowstone
					if (mat == 11) return vec4(fireSpecialLightColor, 0.0); // Jack o'Lantern
					if (mat == 12) return vec4(fireSpecialLightColor, 0.0); // Lantern
					if (mat == 13) return vec4(lavaSpecialLightColor, 0.8); // Lava
				}
			} else {
				if (mat < 20) {
					if (mat == 14) return vec4(lavaSpecialLightColor, 0.0); // Lava Cauldron
					if (mat == 15) return vec4(fireSpecialLightColor, 0.0); // Campfire:Lit
					if (mat == 16) return vec4(vec3(1.7, 0.9, 0.4) * 4.0, 0.0); // Redstone Lamp:Lit
					if (mat == 17) return vec4(vec3(1.7, 0.9, 0.4) * 2.0, 0.0); // Respawn Anchor:Lit
					if (mat == 18) return vec4(vec3(1.0, 1.25, 1.5) * 3.4, 0.0); // Sea Lantern
					if (mat == 19) return vec4(vec3(3.0, 0.9, 0.2) * 3.0, 0.0); // Shroomlight
				} else {
					if (mat == 20) return vec4(vec3(2.3, 0.9, 0.2) * 3.4, 0.0); // Cave Vines:With Glow Berries
					if (mat == 21) return vec4(fireSpecialLightColor * 0.7, 0.0); // Furnace:Lit
					if (mat == 22) return vec4(fireSpecialLightColor * 0.7, 0.0); // Smoker:Lit
					if (mat == 23) return vec4(fireSpecialLightColor * 0.7, 0.0); // Blast Furnace:Lit
					if (mat == 24) return vec4(fireSpecialLightColor * 0.25 * candleColorMult, candleExtraLight); // Standard Candles:Lit
					if (mat == 25) return vec4(netherPortalSpecialLightColor * 2.0, 0.4); // Nether Portal
				}
			}
		} else {
			if (mat < 38) {
				if (mat < 32) {
					if (mat == 26) return vec4(netherPortalSpecialLightColor, 0.0); // Crying Obsidian
					if (mat == 27) return soulFireSpecialColor; // Soul Fire
					if (mat == 28) return soulFireSpecialColor; // Soul Torch
					if (mat == 29) return soulFireSpecialColor; // Soul Lantern
					if (mat == 30) return soulFireSpecialColor; // Soul Campfire:Lit
					if (mat == 31) return vec4(redstoneSpecialLightColor * 0.5, 0.1); // Redstone Ores:Lit
				} else {
					if (mat == 32) return vec4(redstoneSpecialLightColor * 0.3, 0.1); // Redstone Ores:Unlit
					if (mat == 33) return vec4(vec3(1.4, 1.1, 0.5), 0.0); // Enchanting Table
                    #if GLOWING_LICHEN > 0
						if (mat == 34) return vec4(vec3(0.8, 1.1, 1.1), 0.05); // Glow Lichen with IntegratedPBR
					#else
						if (mat == 34) return vec4(vec3(0.4, 0.55, 0.55), 0.0); // Glow Lichen vanilla
					#endif
					if (mat == 35) return vec4(redstoneSpecialLightColor * 0.25, 0.0); // Redstone Torch
					if (mat == 36) return vec4(vec3(0.325, 0.15, 0.425) * 2.0, 0.05); // Amethyst Cluster, Amethyst Buds, Calibrated Sculk Sensor
					if (mat == 37) return vec4(lavaSpecialLightColor * 0.1, 0.1); // Magma Block
				}
			} else {
				if (mat < 44) {
					if (mat == 38) return vec4(vec3(2.0, 0.5, 1.5) * 0.3, 0.1); // Dragon Egg
					if (mat == 39) return vec4(vec3(2.0, 1.0, 1.5) * 0.25, 0.1); // Chorus Flower
					if (mat == 40) return vec4(vec3(2.5, 1.2, 0.4) * 0.1, 0.1); // Brewing Stand
					if (mat == 41) return vec4(redstoneSpecialLightColor * 0.4, 0.15); // Redstone Block
					if (mat == 42) return vec4(vec3(0.75, 0.75, 3.0) * 0.277, 0.15); // Lapis Block
					if (mat == 43) return vec4(vec3(1.7, 0.9, 0.4) * 0.45, 0.05); // Iron Ores
				} else {
					if (mat == 44) return vec4(vec3(1.7, 1.1, 0.2) * 0.45, 0.1); // Gold Ores
					if (mat == 45) return vec4(vec3(1.7, 0.8, 0.4) * 0.45, 0.05); // Copper Ores
					if (mat == 46) return vec4(vec3(0.75, 0.75, 3.0) * 0.2, 0.1); // Lapis Ores
					if (mat == 47) return vec4(vec3(0.5, 3.5, 0.5) * 0.3, 0.1); // Emerald Ores
					if (mat == 48) return vec4(vec3(0.5, 2.0, 2.0) * 0.4, 0.15); // Diamond Ores
					if (mat == 49) return vec4(vec3(1.5, 1.5, 1.5) * 0.3, 0.05); // Nether Quartz Ore
				}
			}
		}
	} else {
		if (mat < 74) {
			if (mat < 62) {
				if (mat < 56) {
					if (mat == 50) return vec4(vec3(1.7, 1.1, 0.2) * 0.45, 0.05); // Nether Gold Ore
					if (mat == 51) return vec4(vec3(1.7, 1.1, 0.2) * 0.45, 0.05); // Gilded Blackstone
					if (mat == 52) return vec4(vec3(1.8, 0.8, 0.4) * 0.6, 0.15); // Ancient Debris
					if (mat == 53) return vec4(vec3(1.4, 0.2, 1.4) * 0.3, 0.05); // Spawner
					if (mat == 54) return vec4(vec3(3.1, 1.1, 0.3) * 1.0, 0.1); // Trial Spawner:NotOminous:Active, Vault:NotOminous:Active
					if (mat == 55) return vec4(vec3(1.7, 0.9, 0.4) * 4.0, 0.0); // Copper Bulb:BrighterOnes:Lit
				} else {
					if (mat == 56) return vec4(vec3(1.7, 0.9, 0.4) * 2.0, 0.0); // Copper Bulb:DimmerOnes:Lit
					if (mat == 57) return vec4(vec3(0.1, 0.3, 0.4) * 0.5, 0.0005); // Sculk++
					if (mat == 58) return vec4(vec3(0.0, 1.4, 1.4) * 4.0, 0.15); // End Portal Frame:Active
					if (mat == 59) return vec4(0.0); // Bedrock
					if (mat == 60) return vec4(vec3(3.1, 1.1, 0.3) * 0.125, 0.0125); // Command Block
					if (mat == 61) return vec4(vec3(3.0, 0.9, 0.2) * 0.125, 0.0125); // Warped Fungus, Crimson Fungus
				}
			} else {
				if (mat < 68) {
					if (mat == 62) return vec4(vec3(3.5, 0.6, 0.4) * 0.3, 0.05); // Crimson Stem, Crimson Hyphae
					if (mat == 63) return vec4(vec3(0.3, 1.9, 1.5) * 0.3, 0.05); // Warped Stem, Warped Hyphae
					if (mat == 64) return vec4(vec3(1.0, 1.0, 1.0) * 0.45, 0.1); // Structure Block, Jigsaw Block, Test Block, Test Instance Block
					if (mat == 65) return vec4(vec3(3.0, 0.9, 0.2) * 0.125, 0.0125); // Weeping Vines Plant
					if (mat == 66) return vec4(redstoneSpecialLightColor * 0.05, 0.002); // Redstone Wire:Lit, Comparator:Unlit:Subtract
					if (mat == 67) return vec4(redstoneSpecialLightColor * 0.125, 0.0125); // Repeater:Lit, Comparator:Lit
				} else {
					if (mat == 68) return vec4(vec3(0.75), 0.0); // Vault:Inactive
					if (mat == 69) return vec4(vec3(1.3, 1.6, 1.6) * 1.0, 0.1); // Trial Spawner:Ominous:Active, Vault:Ominous:Active
					if (mat == 70) return vec4(vec3(1.0, 0.1, 0.1) * candleColorMult, candleExtraLight); // Red Candles:Lit
					if (mat == 71) return vec4(vec3(1.0, 0.4, 0.1) * candleColorMult, candleExtraLight); // Orange Candles:Lit
					if (mat == 72) return vec4(vec3(1.0, 1.0, 0.1) * candleColorMult, candleExtraLight); // Yellow Candles:Lit
					if (mat == 73) return vec4(vec3(0.1, 1.0, 0.1) * candleColorMult, candleExtraLight); // Lime Candles:Lit
				}
			}
		} else {
			if (mat < 86) {
				if (mat < 80) {
					if (mat == 74) return vec4(vec3(0.3, 1.0, 0.3) * candleColorMult, candleExtraLight); // Green Candles:Lit
					if (mat == 75) return vec4(vec3(0.3, 0.8, 1.0) * candleColorMult, candleExtraLight); // Cyan Candles:Lit
					if (mat == 76) return vec4(vec3(0.5, 0.65, 1.0) * candleColorMult, candleExtraLight); // Light Blue Candles:Lit
					if (mat == 77) return vec4(vec3(0.1, 0.15, 1.0) * candleColorMult, candleExtraLight); // Blue Candles:Lit
					if (mat == 78) return vec4(vec3(0.7, 0.3, 1.0) * candleColorMult, candleExtraLight); // Purple Candles:Lit
					if (mat == 79) return vec4(vec3(1.0, 0.1, 1.0) * candleColorMult, candleExtraLight); // Magenta Candles:Lit
				} else {
					if (mat == 80) return vec4(vec3(1.0, 0.4, 1.0) * candleColorMult, candleExtraLight); // Pink Candles:Lit
					if (mat == 81) return vec4(vec3(2.8, 1.1, 0.2) * 0.125, 0.0125); // Open Eyeblossom
					if (mat == 82) return vec4(vec3(2.8, 1.1, 0.2) * 0.3, 0.05); // Creaking Heart: Active
					if (mat == 83) return vec4(vec3(1.6, 1.6, 0.7) * 0.3, 0.05); // Firefly Bush
					if (mat == 84) return vec4(0.0);
					if (mat == 85) return vec4(0.0);
				}
			} else {
				if (mat < 92) {
					if (mat == 86) return vec4(0.0);
					if (mat == 87) return vec4(0.0);
					if (mat == 88) return vec4(0.0);
					if (mat == 89) return vec4(0.0);
					if (mat == 90) return vec4(0.0);
					if (mat == 91) return vec4(0.0);
				} else {
					if (mat == 92) return vec4(0.0);
					if (mat == 93) return vec4(0.0);
					if (mat == 94) return vec4(0.0);
					if (mat == 95) return vec4(0.0);
					if (mat == 96) return vec4(0.0);
					if (mat == 97) return vec4(0.0);
				}
			}
		}
	}

	return vec4(blocklightCol * 20.0, 0.0);
}

// ---------------------------------------------------------------------------
// Per-texel emissive mask (no labPBR): isolate the genuinely glowing texels of
// a light-emitting block from its non-emitting parts (a torch's wooden stick, a
// lantern's iron cage) using albedo alone. We key off the channel MAXIMUM (value)
// rather than luminance so deep-but-saturated emitters (redstone, soul fire) are
// not unfairly dimmed by the luma weights. A mild saturation bonus pulls warm /
// vivid pixels above the threshold while keeping grey structural pixels below it.
#ifndef EMISSIVE_THRESHOLD_LO
#define EMISSIVE_THRESHOLD_LO 0.42
#endif
#ifndef EMISSIVE_THRESHOLD_HI
#define EMISSIVE_THRESHOLD_HI 0.72
#endif
float emissiveMask(vec3 albedo) {
    float maxc = max(albedo.r, max(albedo.g, albedo.b));
    float minc = min(albedo.r, min(albedo.g, albedo.b));
    float sat  = (maxc - minc) / max(maxc, 1e-4);
    float key  = clamp(maxc + sat * 0.25 * maxc, 0.0, 1.0); // saturated highlights count for more
    return smoothstep(EMISSIVE_THRESHOLD_LO, EMISSIVE_THRESHOLD_HI, key);
}

// ---------------------------------------------------------------------------
// Per-MATERIAL emissive mask:
// brightness alone can't tell a torch's flame from its pale stick or a campfire's
// flame from its logs, because the wood is bright too. The discriminator is HUE +
// SATURATION: an emissive flame is a saturated warm/cyan hue, while wood, stone
// and metal cages are desaturated. We classify by the known light material and
// gate the per-texel albedo on the hue/saturation/value that block's glow occupies.
vec3 rgbToHsl(vec3 c) {
    float mx = max(c.r, max(c.g, c.b));
    float mn = min(c.r, min(c.g, c.b));
    float l  = (mx + mn) * 0.5;
    float h  = 0.0, s = 0.0;
    float d  = mx - mn;
    if (d > 1e-5) {
        s = (l > 0.5) ? d / max(2.0 - mx - mn, 1e-5) : d / max(mx + mn, 1e-5);
        if      (mx == c.r) h = (c.g - c.b) / d + (c.g < c.b ? 6.0 : 0.0);
        else if (mx == c.g) h = (c.b - c.r) / d + 2.0;
        else                h = (c.r - c.g) / d + 4.0;
        h /= 6.0;
    }
    return vec3(h, s, l); // hue 0..1, sat 0..1, lightness 0..1
}

// 1 when hue01 is within `width` degrees of `targetDeg`, fading to 0 by 1.5*width.
float isolateHue(float hue01, float targetDeg, float widthDeg) {
    float d = abs(hue01 * 360.0 - targetDeg);
    d = min(d, 360.0 - d);
    return 1.0 - smoothstep(widthDeg, widthDeg * 1.5, d);
}

float emissiveMaskForMat(int mat, vec3 albedo) {
    vec3  hsl = rgbToHsl(albedo);
    float val = max(albedo.r, max(albedo.g, albedo.b));
    float sat = hsl.y;

    // white-hot flame tip / filament: very bright AND desaturated -> the warm-hue
    // gates below would miss it, so add it back for every flame.
    float whiteHot = smoothstep(0.90, 1.0, val) * (1.0 - smoothstep(0.20, 0.50, sat));

    // Soul fire family (cyan flame): emit the saturated cyan, drop the wood/cage.
    if (mat == 27 || mat == 28 || mat == 29 || mat == 30) {
        float cyan = isolateHue(hsl.x, 188.0, 50.0);
        return clamp(max(cyan * smoothstep(0.22, 0.48, sat) * smoothstep(0.42, 0.72, val), whiteHot), 0.0, 1.0);
    }
    // Warm fire / flame blocks (torch, fire, lantern, campfire, furnaces, candles,
    // copper bulb, brewing stand): the flame is a SATURATED orange/yellow. Wood,
    // birch logs and metal cages share the warm hue but are far less saturated, so
    // the saturation gate is what rejects them (this is the campfire-log fix).
    if (mat == 2 || mat == 5 || mat == 11 || mat == 12 || mat == 15 ||
        mat == 21 || mat == 22 || mat == 23 || mat == 40 || mat == 55 || mat == 56 ||
        mat == 24 || (mat >= 70 && mat <= 80)) {
        float orange = isolateHue(hsl.x, 42.0, 42.0);
        return clamp(max(orange * smoothstep(0.42, 0.62, sat) * smoothstep(0.45, 0.72, val), whiteHot), 0.0, 1.0);
    }
    // Redstone (ore specks, torch, wire, repeater, block): saturated red only.
    if (mat == 31 || mat == 32 || mat == 35 || mat == 41 || mat == 66 || mat == 67) {
        float redness = clamp(albedo.r - max(albedo.g, albedo.b), 0.0, 1.0);
        return clamp(smoothstep(0.12, 0.30, redness) * smoothstep(0.28, 0.52, val), 0.0, 1.0);
    }
    // Face emitters (glowstone, sea lantern, froglight, lava, magma, shroomlight,
    // end rod, beacon, redstone lamp...): the whole face glows, BUT the texture
    // still has darker detail — mortar lines, cracks, froglight pores, lava crust
    // veins — that must stay dark, otherwise the block bleaches to a flat slab of
    // light. So track the per-texel brightness with a steep cubic (no floor): the
    // bright cells blaze while the dark grout emits ~nothing, preserving the texture.
    if (mat == 3 || mat == 4 || mat == 7 || mat == 8 || mat == 9 || mat == 10 ||
        mat == 13 || mat == 14 || mat == 16 || mat == 17 || mat == 18 || mat == 19 ||
        mat == 37 || mat == 58) {
        float v = smoothstep(0.12, 1.0, val);
        return v * v * v;
    }
    // Metal ores with small glowing flecks (gold, iron, copper, lapis, emerald,
    // diamond, quartz, nether gold, gilded blackstone, ancient debris): emit the
    // bright saturated speck only.
    if (mat >= 43 && mat <= 52) {
        return clamp(smoothstep(0.45, 0.72, val) * smoothstep(0.18, 0.40, sat), 0.0, 1.0);
    }
    // Everything else (amethyst, dragon egg, chorus, glow lichen, sculk, legacy
    // emissive...): generic brightness + mild saturation bonus.
    return emissiveMask(albedo);
}

// HDR intensity of a special-light material, normalised so the brightest vanilla
// emitter (~end rod / glowstone, total ~12-16) maps near 1.0. Used to scale the
// self-emission so lava/glowstone blaze while dim emitters (redstone ore, glow
// lichen) only faintly glow.
float specialLightIntensity(int mat) {
    vec4 c = GetSpecialBlocklightColor(mat);
    return clamp(GetLuminance(c.rgb) / 4.0, 0.0, 1.0);
}

#endif // BLOCKLIGHT_COLORS_GLSL
