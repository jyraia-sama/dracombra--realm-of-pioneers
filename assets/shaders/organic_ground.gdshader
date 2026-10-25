shader_type canvas_item;
// Sol aux bords organiques : redessine le calque Ground à partir de ses propres tuiles,
// mais les limites entre terrains (herbe, terre, eau, pavés...) suivent un bruit au lieu
// des bords des cases. Tout reste au pixel près.
//
// types (aussi la texture du sprite) : une case par texel.
//   R = source de la tuile, G = colonne, B = ligne dans l'atlas (x / 255),
//   A = matériau + 1 (0 = case vide).

render_mode unshaded;

uniform sampler2D types : filter_nearest;
uniform sampler2D atlas0 : filter_nearest;
uniform sampler2D atlas1 : filter_nearest;
uniform int tile = 16;
// Amplitude des ondulations des bords, en pixels.
uniform float wobble = 5.0;
// Taille des « vagues » du bruit, en pixels.
uniform float noise_scale = 14.0;
uniform int seed = 7;

// Matériaux (voir ground_painter.gd).
const int GRASS = 1;
const int FOREST = 2;
const int DIRT = 3;
const int WATER = 4;
const int FORD = 5;
const int PAVING = 6;
const int SLABS = 7;
const int RUBBLE = 8;

float hash(ivec2 p) {
	int h = p.x * 374761393 + p.y * 668265263 + seed * 2147483;
	h = (h ^ (h >> 13)) * 1274126177;
	h = h ^ (h >> 16);
	return float(h & 65535) / 65535.0;
}

float value_noise(vec2 p, int salt) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	ivec2 c = ivec2(i) + ivec2(salt * 131, salt * 71);
	float a = hash(c);
	float b = hash(c + ivec2(1, 0));
	float d = hash(c + ivec2(0, 1));
	float e = hash(c + ivec2(1, 1));
	return mix(mix(a, b, f.x), mix(d, e, f.x), f.y);
}

vec4 cell_data(ivec2 cell) {
	ivec2 s = textureSize(types, 0);
	cell = clamp(cell, ivec2(0), s - 1);
	return texelFetch(types, cell, 0);
}

int material_of(vec4 d) {
	return int(round(d.a * 255.0)) - 1;
}

bool organic(int m) {
	return m == GRASS || m == FOREST || m == DIRT || m == RUBBLE || m == PAVING;
}

// La case dont on prend le dessin pour le pixel `px` (coordonnées en pixels du calque).
// On regarde les 4 centres de cases les plus proches : chaque terrain y reçoit un poids
// (interpolation bilinéaire), plus un peu de bruit propre à ce terrain. Le plus fort
// l'emporte : les angles s'arrondissent, les diagonales en escalier deviennent des courbes.
ivec2 pick_cell(ivec2 px) {
	ivec2 cell0 = px / tile;
	int m0 = material_of(cell_data(cell0));
	vec2 p = vec2(px) / noise_scale;
	vec2 n = vec2(value_noise(p, 1), value_noise(p, 2)) - 0.5;
	vec2 g = (vec2(px) + n * wobble) / float(tile) - 0.5;
	ivec2 base = ivec2(floor(g));
	vec2 f = fract(g);
	ivec2 cells[4] = ivec2[4](base, base + ivec2(1, 0), base + ivec2(0, 1), base + ivec2(1, 1));
	float w[4] = float[4]((1.0 - f.x) * (1.0 - f.y), f.x * (1.0 - f.y), (1.0 - f.x) * f.y, f.x * f.y);
	int mats[4];
	for (int i = 0; i < 4; i++) {
		mats[i] = material_of(cell_data(cells[i]));
	}
	int best = 0;
	float best_score = -1.0;
	for (int i = 0; i < 4; i++) {
		if (mats[i] < 0) {
			continue;
		}
		float score = 0.0;
		for (int j = 0; j < 4; j++) {
			if (mats[j] == mats[i]) {
				score += w[j];
			}
		}
		score += (value_noise(p * 1.6, 10 + mats[i]) - 0.5) * 0.45 + w[i] * 0.01;
		if (score > best_score) {
			best_score = score;
			best = i;
		}
	}
	int mb = mats[best];
	if (mb < 0 || m0 < 0) {
		return cell0;
	}
	// Pavés et dalles gardent leur grille à l'intérieur de leur zone.
	if (mb == m0 && !organic(m0)) {
		return cell0;
	}
	return cells[best];
}

int material_at(ivec2 px) {
	return material_of(cell_data(pick_cell(px)));
}

vec4 tile_pixel(ivec2 px) {
	ivec2 cell = pick_cell(px);
	vec4 d = cell_data(cell);
	if (material_of(d) < 0) {
		return vec4(0.0);
	}
	ivec2 local = ivec2(((px % tile) + tile) % tile);
	ivec2 at = ivec2(round(vec2(d.g, d.b) * 255.0)) * tile + local;
	if (d.r * 255.0 > 0.5) {
		return texelFetch(atlas1, at, 0);
	}
	return texelFetch(atlas0, at, 0);
}

bool greenish(int m) {
	return m == GRASS || m == FOREST;
}

void fragment() {
	ivec2 size = textureSize(types, 0) * tile;
	ivec2 px = ivec2(floor(UV * vec2(size)));
	vec4 col = tile_pixel(px);
	int m = material_at(px);
	int up = material_at(px + ivec2(0, -1));
	int dn = material_at(px + ivec2(0, 1));
	int lf = material_at(px + ivec2(-1, 0));
	int rt = material_at(px + ivec2(1, 0));
	bool touches_green = greenish(up) || greenish(dn) || greenish(lf) || greenish(rt);
	if ((m == DIRT || m == RUBBLE) && touches_green) {
		// Bord de terre : une ligne plus sombre, comme une petite marche.
		col.rgb *= 0.72;
	} else if (m == WATER) {
		if (touches_green || up == DIRT || dn == DIRT || lf == DIRT || rt == DIRT) {
			// La berge.
			col.rgb = mix(col.rgb, vec3(0.24, 0.17, 0.11), 0.75);
		} else {
			int up2 = material_at(px + ivec2(0, -2));
			int up3 = material_at(px + ivec2(0, -3));
			if (up2 != WATER || up3 != WATER) {
				// L'ombre de la berge sur l'eau, côté nord.
				col.rgb *= 0.7;
			} else if (dn != WATER || material_at(px + ivec2(0, 2)) != WATER) {
				// Un liseré d'écume au pied de la berge.
				col.rgb = mix(col.rgb, vec3(0.75, 0.88, 0.95), 0.45);
			}
		}
	} else if (greenish(m) && (dn == DIRT || dn == WATER || dn == RUBBLE || dn == PAVING || dn == SLABS)) {
		// L'herbe déborde un peu : liseré clair sur son bord.
		col.rgb *= 1.18;
	} else if ((m == PAVING || m == SLABS) && touches_green) {
		col.rgb *= 0.85;
	}
	COLOR = col;
}
