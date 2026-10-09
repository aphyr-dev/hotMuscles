shader_type canvas_item;
// bodyMap.gdshader - draws one baked body map for BodyView (tools/appData/bakeBodyMaps.py makes them)
// what this offers
// - TEXTURE is the map: red = what is there (0 outside, 1 seam, 2 head/hands/feet, 3+ a region),
//   green = where along its outline a texel near a muscle's edge sits (ghost dash position),
//   blue = distance from the texel's centre to the edge of what it belongs to (edgeSteps per texel)
// - palette (64 x 2, BodyView rewrites it when the heat changes): row 0 = colour per id,
//   row 1 = red: ghost strength (0 = not in the ghost), green: 1 = the selected region
// - fill: zoomed in, the 4 texels round a point vote by their edge distances (signed per id and
//   blended), which puts every edge where the real outline runs with a 1 px soft edge at any zoom
//   (an id map must never be filtered as numbers); zoomed out (thumbnails), a grid of texels across
//   the pixel is averaged
// - ghost preview: translucent pulsing fill + dashed outline; selected region: white line on a
//   dark halo; both found by searching round each pixel for where the region ends, so their widths
//   stay in local px at any zoom
// the map is only ever read with texelFetch inside fragment() (4.3 cannot hand TEXTURE to a
// function), so the reads are macros and the helper functions take ids, not the texture

/// UNIFORMS ///

uniform sampler2D palette : filter_nearest;
// map texels per local px at the current zoom (BodyView sets it)
uniform highp float texelsPerPx = 1.0;
// false skips every outline search (nothing selected, no ghost)
uniform bool outlinesOn = false;
// ghost pulse, 0 = dim end, 1 = bright end
uniform float pulse = 0.0;
uniform vec4 ghostColour = vec4(0.5, 0.94, 1.0, 1.0);
uniform vec4 haloColour = vec4(0.043, 0.047, 0.059, 1.0);
uniform vec4 lineColour = vec4(1.0, 1.0, 1.0, 1.0);
// widths in local px, fill and line strengths, and the drawn share of each dash period
uniform float selectedOutlinePx = 2.5;
uniform float selectedHaloPx = 6.0;
uniform float ghostOutlinePx = 2.2;
uniform float ghostFillLow = 0.18;
uniform float ghostFillHigh = 0.5;
uniform float ghostLineLow = 0.55;
uniform float ghostDashShare = 0.6;
// blue steps per texel of edge distance (AppData.mapEdgeSteps)
uniform float edgeSteps = 64.0;
// how much the figure fades toward the card colour under an overlay drawn on top (the cardio
// vessels), 0 = not at all
uniform float dim = 0.0;
uniform vec3 dimColour = vec3(0.0);

/// TUNING ///

// largest texel grid averaged per pixel when zoomed out
const int maxGrid = 6;
// outline search: directions round the pixel and steps out along each
const int searchDirections = 12;
const int searchSteps = 6;
// cheap first look before a search: points on two rings round the pixel
const int lookPoints = 8;

/// MAP READS (fragment only - they use its `size`) ///

#define mapAt(texel) texelFetch(TEXTURE, clamp((texel), ivec2(0), size - ivec2(1)), 0)
#define idAt(texel) int(mapAt(texel).r * 255.0 + 0.5)
#define quadMasks(base, f) signedMasks(mapAt(base), mapAt((base) + ivec2(1, 0)), mapAt((base) + ivec2(0, 1)), mapAt((base) + ivec2(1, 1)), f)

/// HELPERS ///

vec4 colourOf(int id) {
	return texelFetch(palette, ivec2(id, 0), 0);
}

vec4 flagsOf(int id) {
	return texelFetch(palette, ivec2(id, 1), 0);
}

vec4 bilinear(vec2 f) {
	// weights of the 4 texels round a point, f = position inside the cell
	return vec4((1.0 - f.x) * (1.0 - f.y), f.x * (1.0 - f.y), (1.0 - f.x) * f.y, f.x * f.y);
}

vec4 edgeWeights(ivec4 ids, vec4 edges, vec4 w, float soft) {
	// how much each of the 4 taps counts: for each tap's id, its signed edge distance (+ on its own
	// texels, - on the others) blended bilinearly says how far inside that id the point is; that
	// turns into a coverage soft over `soft` texels, spread back over the id's taps; sums to 1
	vec4 mass = vec4(0.0);
	vec4 inside = vec4(0.0);
	for (int j = 0; j < 4; j++) {
		for (int i = 0; i < 4; i++) {
			if (ids[i] == ids[j]) {
				mass[j] += w[i];
				inside[j] += w[i] * edges[i];
			} else {
				inside[j] -= w[i] * edges[i];
			}
		}
	}
	vec4 cover = clamp(inside / soft + 0.5, 0.0, 1.0);
	vec4 weights = cover * w / max(mass, vec4(0.0001));
	float total = weights.x + weights.y + weights.z + weights.w;
	if (total < 0.0001) {
		return w;
	}
	return weights / total;
}

vec2 signedMasks(vec4 tap0, vec4 tap1, vec4 tap2, vec4 tap3, vec2 f) {
	// how far (texels) a point is inside the ghost (x) and inside the selected region (y): each of the
	// 4 texels round it adds its edge distance, + when it is in the area and - when not, blended
	// bilinearly - negative = outside, and the edge sits where it crosses 0, smooth at any zoom
	vec4 w = bilinear(f);
	vec4 taps[4] = vec4[4](tap0, tap1, tap2, tap3);
	vec2 m = vec2(0.0);
	for (int j = 0; j < 4; j++) {
		vec4 flags = flagsOf(int(taps[j].r * 255.0 + 0.5));
		float edge = taps[j].b * (255.0 / edgeSteps);
		vec2 sides = vec2(step(0.001, flags.r), step(0.5, flags.g)) * 2.0 - 1.0;
		m += sides * edge * w[j];
	}
	return m;
}

vec4 over(vec4 below, vec3 rgb, float alpha) {
	// straight colour `rgb` at `alpha` laid over a straight colour
	float outAlpha = alpha + below.a * (1.0 - alpha);
	vec3 outRgb = (rgb * alpha + below.rgb * below.a * (1.0 - alpha)) / max(outAlpha, 0.0001);
	return vec4(outRgb, outAlpha);
}

float lineCover(float distance, float halfWidth, float soft) {
	// 1 inside a line of halfWidth round distance 0, with a soft edge `soft` wide (all local px)
	return 1.0 - smoothstep(halfWidth - soft * 0.5, halfWidth + soft * 0.5, distance);
}

/// MAIN ///

void fragment() {
	ivec2 size = textureSize(TEXTURE, 0);
	highp vec2 t = UV * vec2(size);
	// texels per screen pixel, and one screen pixel in local px
	vec2 footprint = vec2(abs(dFdx(t).x) + abs(dFdy(t).x), abs(dFdx(t).y) + abs(dFdy(t).y));
	float texelsPerScreenPx = max(max(footprint.x, footprint.y), 0.0001);
	float screenPx = texelsPerScreenPx / max(texelsPerPx, 0.0001);

	// fill
	vec4 sum = vec4(0.0);
	float ghost = 0.0;
	if (texelsPerScreenPx <= 1.0) {
		// zoomed in: the 4 taps, sharpened to a one-pixel edge
		highp vec2 p = t - vec2(0.5);
		highp vec2 cell = floor(p);
		ivec2 base = ivec2(cell);
		vec4 tap0 = mapAt(base);
		vec4 tap1 = mapAt(base + ivec2(1, 0));
		vec4 tap2 = mapAt(base + ivec2(0, 1));
		vec4 tap3 = mapAt(base + ivec2(1, 1));
		ivec4 ids = ivec4(vec4(tap0.r, tap1.r, tap2.r, tap3.r) * 255.0 + 0.5);
		vec4 edges = vec4(tap0.b, tap1.b, tap2.b, tap3.b) * (255.0 / edgeSteps);
		vec4 weights = edgeWeights(ids, edges, bilinear(p - cell), texelsPerScreenPx);
		for (int j = 0; j < 4; j++) {
			vec4 c = colourOf(ids[j]);
			sum += vec4(c.rgb * c.a, c.a) * weights[j];
			ghost += flagsOf(ids[j]).r * weights[j];
		}
	} else {
		// zoomed out: average an n x n grid of texels over the pixel's footprint
		ivec2 n = ivec2(clamp(ceil(footprint), vec2(2.0), vec2(float(maxGrid))));
		float count = float(n.x * n.y);
		for (int gy = 0; gy < maxGrid; gy++) {
			if (gy >= n.y) {
				break;
			}
			for (int gx = 0; gx < maxGrid; gx++) {
				if (gx >= n.x) {
					break;
				}
				highp vec2 q = t + ((vec2(float(gx), float(gy)) + 0.5) / vec2(n) - 0.5) * footprint;
				int id = idAt(ivec2(floor(q)));
				vec4 c = colourOf(id);
				sum += vec4(c.rgb * c.a, c.a) / count;
				ghost += flagsOf(id).r / count;
			}
		}
	}
	vec4 colour = vec4(sum.rgb / max(sum.a, 0.0001), sum.a);
	if (ghost > 0.0) {
		float fillAlpha = mix(ghostFillLow, ghostFillHigh, pulse) * ghost;
		colour.rgb = mix(colour.rgb, ghostColour.rgb, fillAlpha);
	}

	// ghost outline and selected region
	if (outlinesOn) {
		float reach = (selectedHaloPx * 0.5 + screenPx) * texelsPerPx;

		// cheap first look: any ghost or selected texel at the centre or on two rings round it
		bool near = false;
		for (int k = 0; k <= lookPoints * 2; k++) {
			highp vec2 q = t;
			if (k > 0) {
				float angle = 6.2831853 * float(k) / float(lookPoints);
				float radius = reach;
				if (k <= lookPoints) {
					radius = reach * 0.5;
				}
				q = t + vec2(cos(angle), sin(angle)) * radius;
			}
			vec4 flags = flagsOf(idAt(ivec2(floor(q))));
			if (flags.r > 0.001 || flags.g > 0.5) {
				near = true;
				break;
			}
		}

		if (near) {
			// walk out along each direction; the edge is where the bilinear mask crosses one half
			vec2 edge = vec2(reach);
			highp vec2 dashPoint = t;
			float stepLength = reach / float(searchSteps);
			highp vec2 p0 = t - vec2(0.5);
			highp vec2 cell0 = floor(p0);
			vec2 centre = quadMasks(ivec2(cell0), p0 - cell0);
			for (int d = 0; d < searchDirections; d++) {
				float angle = 6.2831853 * float(d) / float(searchDirections);
				vec2 direction = vec2(cos(angle), sin(angle));
				vec2 previous = centre;
				bool foundGhost = false;
				bool foundSelected = false;
				for (int s = 1; s <= searchSteps; s++) {
					highp vec2 p = t + direction * (float(s) * stepLength) - vec2(0.5);
					highp vec2 cell = floor(p);
					vec2 here = quadMasks(ivec2(cell), p - cell);
					// ghost edge (and the point just inside it, for the dash position)
					if (!foundGhost && (previous.x >= 0.0) != (here.x >= 0.0)) {
						foundGhost = true;
						float along = (float(s) - 1.0 + previous.x / (previous.x - here.x)) * stepLength;
						if (along < edge.x) {
							edge.x = along;
							float inward = 1.0;
							if (centre.x >= 0.0) {
								inward = -1.0;
							}
							dashPoint = t + direction * (along + inward);
						}
					}
					// selected region edge
					if (!foundSelected && (previous.y >= 0.0) != (here.y >= 0.0)) {
						foundSelected = true;
						float along = (float(s) - 1.0 + previous.y / (previous.y - here.y)) * stepLength;
						edge.y = min(edge.y, along);
					}
					previous = here;
				}
			}
			vec2 edgePx = edge / texelsPerPx;

			// dashed ghost line
			if (edge.x < reach) {
				ivec2 dashTexel = clamp(ivec2(floor(dashPoint)), ivec2(0), size - ivec2(1));
				float dashPosition = texelFetch(TEXTURE, dashTexel, 0).g;
				float dash = 1.0 - step(ghostDashShare, dashPosition);
				float lineAlpha = mix(ghostLineLow, 1.0, pulse) * dash * lineCover(edgePx.x, ghostOutlinePx * 0.5, screenPx);
				colour = over(colour, ghostColour.rgb, lineAlpha);
			}

			// selected: white line on a dark halo
			if (edge.y < reach) {
				colour = over(colour, haloColour.rgb, haloColour.a * lineCover(edgePx.y, selectedHaloPx * 0.5, screenPx));
				colour = over(colour, lineColour.rgb, lineColour.a * lineCover(edgePx.y, selectedOutlinePx * 0.5, screenPx));
			}
		}
	}
	colour.rgb = mix(colour.rgb, dimColour, dim);
	COLOR = colour;
}
