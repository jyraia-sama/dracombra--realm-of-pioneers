shader_type canvas_item;
// Sol aux bords organiques : redessine le calque Ground à partir de ses propres tuiles,
// mais les limites entre terrains (herbe, terre, eau, pavés...) suivent un bruit au lieu
// des bords des cases. Tout reste au pixel près.
//
// types (aussi la texture du sprite) : une case par texel.
//   R = source de la tuile, G = colonne, B = ligne dans l'atlas (x / 255),
//   A = matériau + 1 (0 = case vide).



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
const int ROCK = 9;
const int CAVE = 10;
const int LAIR = 11;

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
	return m == GRASS || m == FOREST || m == DIRT || m == RUBBLE || m == PAVING || m == ROCK || m == CAVE || m == LAIR;
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

// ------------------------------------------------------------------ sol dessiné
// Herbe, terre, sous-bois et eau ne viennent plus des tuiles : aplats calmes, grandes
// taches douces, quelques touffes et fleurs. Les détails et le contraste sont laissés
// aux objets (arbres, ruines, maisons), qui ressortent sur un sol tranquille.
uniform bool painted = true;
// Falaises (roche du calque Walls) : dessus, pan de roche tourné vers la caméra.
uniform vec3 rock_top = vec3(0.16, 0.14, 0.19);
uniform vec3 rock_top_light = vec3(0.22, 0.20, 0.26);
uniform vec3 rock_face = vec3(0.42, 0.38, 0.44);
uniform vec3 rock_face_dark = vec3(0.30, 0.27, 0.33);
uniform vec3 rock_face_light = vec3(0.55, 0.50, 0.55);
uniform int face_height = 14;
// Sol de grotte.
uniform vec3 cave_floor = vec3(0.42, 0.36, 0.34);
uniform vec3 cave_floor_dark = vec3(0.37, 0.31, 0.30);
uniform vec3 cave_floor_light = vec3(0.47, 0.41, 0.38);

vec3 rgb(int r, int g, int b) {
	return vec3(float(r), float(g), float(b)) / 255.0;
}

// Grandes taches : 0 = sombre, 1 = normal, 2 = clair.
int patch_level(ivec2 px, int salt) {
	vec2 p = vec2(px);
	float n = value_noise(p / 42.0, salt) * 0.7 + value_noise(p / 15.0, salt + 5) * 0.3;
	return n < 0.36 ? 0 : (n > 0.64 ? 2 : 1);
}

// Petit motif posé au hasard dans une case de `cell` pixels. Renvoie 0 (rien) ou 1..n.
// Motifs (5 x 3, lignes de haut en bas) : touffe d'herbe, fleur, cailloux.
int decal(ivec2 px, int cell, float chance, int salt, out int kind) {
	ivec2 b = ivec2(floor(vec2(px) / float(cell)));
	float h = hash(b + ivec2(salt * 97, salt * 31));
	kind = 0;
	if (h > chance) {
		return 0;
	}
	ivec2 o = ivec2(int(hash(b + ivec2(7, salt)) * float(cell - 5)), int(hash(b + ivec2(salt, 13)) * float(cell - 3)));
	ivec2 l = px - b * cell - o;
	if (l.x < 0 || l.y < 0 || l.x > 4 || l.y > 2) {
		return 0;
	}
	kind = int(hash(b + ivec2(3, 3 + salt)) * 3.0);
	int bit = l.y * 5 + l.x;
	// Bits : ligne 0 = bits 0-4, ligne 1 = 5-9, ligne 2 = 10-14.
	int masks[3] = int[3](
		0x0A95,   // touffe : X.X.X / .XXX. / ..X..   (approché)
		0x0462,   // fleur : .X... / XXX.. / .X...
		0x0C03);  // cailloux : XX... / ..... / ..XX.
	int lit[3] = int[3](0x0005, 0x0020, 0x0001);
	if (((masks[kind] >> bit) & 1) == 0) {
		return 0;
	}
	return ((lit[kind] >> bit) & 1) == 1 ? 2 : 1;
}

// Pavés : cellules de Voronoï d'environ 7 px, joint sombre, arête claire en haut.
ivec2 cobble_cell(vec2 p, out float d1, out float d2) {
	vec2 g = floor(p / 7.0);
	d1 = 99.0;
	d2 = 99.0;
	ivec2 best = ivec2(0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			ivec2 c = ivec2(g) + ivec2(x, y);
			vec2 fp = (vec2(c) + vec2(hash(c + ivec2(11, 0)), hash(c + ivec2(0, 17))) * 0.8 + 0.1) * 7.0;
			float d = length(p - fp);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				best = c;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return best;
}

vec3 cobble(ivec2 px) {
	float d1;
	float d2;
	vec2 p = vec2(px) + 0.5;
	ivec2 c = cobble_cell(p, d1, d2);
	if (d2 - d1 < 1.1) {
		return rgb(104, 98, 90);
	}
	float a;
	float b;
	ivec2 above = cobble_cell(p + vec2(0.0, -1.0), a, b);
	float t = hash(c + ivec2(23, 5));
	vec3 col = t < 0.33 ? rgb(170, 162, 142) : (t < 0.66 ? rgb(181, 173, 152) : rgb(160, 152, 134));
	// Mousse : les pavés gagnés par l'herbe, par plaques.
	if (value_noise(vec2(px) / 30.0, 71) > 0.66 && hash(c + ivec2(1, 99)) < 0.6) {
		col = mix(col, rgb(128, 146, 72), 0.55);
	}
	if (above != c || b - a < 1.1) {
		col += vec3(0.06);
	}
	return col;
}

// Dalles de la grande place : 16 px, rangées décalées, joints, quelques fissures.
vec3 slab(ivec2 px) {
	int row = px.y / 16;
	int sx = px.x + (row % 2) * 8;
	ivec2 c = ivec2(sx / 16, row);
	ivec2 l = ivec2(sx % 16, px.y % 16);
	if (l.x == 0 || l.y == 0) {
		return rgb(98, 90, 80);
	}
	float t = hash(c + ivec2(41, 7));
	vec3 col = t < 0.33 ? rgb(166, 156, 134) : (t < 0.66 ? rgb(176, 166, 143) : rgb(157, 147, 127));
	if (l.y == 1 || l.x == 1) {
		col += vec3(0.05);
	}
	if (l.y == 15 || l.x == 15) {
		col -= vec3(0.05);
	}
	// Une fissure de temps en temps.
	if (hash(c + ivec2(3, 77)) < 0.25) {
		int fx = 3 + int(hash(c + ivec2(9, 9)) * 9.0);
		if (abs(l.x - fx - (l.y / 4) % 2) < 1 && l.y > 2 && l.y < 12) {
			col = rgb(132, 124, 112);
		}
	}
	return col;
}

vec3 painted_color(int m, ivec2 px) {
	int k;
	if (m == GRASS) {
		int lv = patch_level(px, 21);
		vec3 c = lv == 0 ? rgb(122, 140, 55) : (lv == 2 ? rgb(146, 161, 71) : rgb(134, 151, 62));
		int d = decal(px, 9, 0.13, 1, k);
		if (d > 0) {
			if (k == 1) {
				c = d == 2 ? rgb(250, 232, 120) : rgb(232, 196, 68);
			} else {
				c = d == 2 ? rgb(162, 176, 84) : rgb(102, 124, 50);
			}
		}
		return c;
	}
	if (m == FOREST) {
		int lv = patch_level(px, 33);
		vec3 c = lv == 0 ? rgb(70, 98, 50) : (lv == 2 ? rgb(92, 118, 56) : rgb(82, 108, 53));
		int d = decal(px, 8, 0.18, 2, k);
		if (d > 0) {
			c = k == 1 ? rgb(150, 110, 60) : (d == 2 ? rgb(108, 132, 60) : rgb(56, 80, 44));
		}
		return c;
	}
	if (m == DIRT) {
		int lv = patch_level(px, 45);
		vec3 c = lv == 0 ? rgb(196, 176, 106) : (lv == 2 ? rgb(214, 196, 126) : rgb(205, 186, 115));
		int d = decal(px, 10, 0.10, 3, k);
		if (d > 0 && k != 1) {
			c = d == 2 ? rgb(226, 212, 150) : rgb(172, 152, 94);
		}
		return c;
	}
	if (m == WATER) {
		int lv = patch_level(px, 57);
		vec3 c = lv == 0 ? rgb(66, 104, 128) : (lv == 2 ? rgb(88, 128, 148) : rgb(76, 116, 138));
		// Reflets : petits traits horizontaux.
		ivec2 b = ivec2(px.x / 12, px.y / 5);
		float h = hash(b + ivec2(5, 9));
		int start = int(hash(b) * 7.0);
		if (h < 0.12 && px.y % 5 == 2 && (px.x % 12) >= start && (px.x % 12) < start + 4) {
			c = rgb(150, 186, 196);
		}
		return c;
	}
	if (m == RUBBLE) {
		int lv = patch_level(px, 46);
		vec3 c = lv == 0 ? rgb(184, 164, 100) : (lv == 2 ? rgb(204, 186, 118) : rgb(195, 175, 108));
		int d = decal(px, 7, 0.22, 4, k);
		if (d > 0) {
			c = d == 2 ? rgb(196, 190, 170) : rgb(140, 132, 118);
		}
		return c;
	}
	if (m == CAVE || m == LAIR) {
		int lv = patch_level(px, 61);
		vec3 c = lv == 0 ? cave_floor_dark : (lv == 2 ? cave_floor_light : cave_floor);
		if (m == LAIR) {
			c = mix(c, vec3(0.50, 0.24, 0.18), 0.35);
		}
		int d = decal(px, 9, 0.14, 6, k);
		if (d > 0 && k != 1) {
			c = d == 2 ? c * 1.18 : c * 0.78;
		}
		return c;
	}
	if (m == PAVING) {
		return cobble(px);
	}
	if (m == SLABS) {
		return slab(px);
	}
	return vec3(-1.0);
}

bool is_painted(int m) {
	return painted && m >= GRASS && m != FORD && m != ROCK;
}

// Une falaise : le dessus de la roche, et sur son bord sud un pan vertical de
// `face_height` pixels, avec des strates, des fissures et une arête claire.
vec4 rock_color(ivec2 px) {
	int below = 0;
	for (int i = 1; i <= 28; i++) {
		if (i > face_height) {
			break;
		}
		if (material_at(px + ivec2(0, i)) != ROCK) {
			below = i;
			break;
		}
	}
	if (below > 0) {
		// Le pan de roche. depth : 0 en haut du pan, face_height - 1 au pied.
		int depth = face_height - below;
		// Facettes de roche irrégulières (cellules de Voronoï étirées), fissures sombres,
		// arête claire en haut de chaque facette, plus sombre vers le pied.
		vec2 q = vec2(float(px.x) / 1.35, float(depth) + float(px.y) * 0.0);
		q.y = float(px.y);
		float d1;
		float d2;
		ivec2 cell = cobble_cell(q * vec2(7.0 / 10.0, 7.0 / 9.0) + vec2(0.5), d1, d2);
		float a1;
		float a2;
		ivec2 above = cobble_cell((q + vec2(0.0, -1.0)) * vec2(7.0 / 10.0, 7.0 / 9.0) + vec2(0.5), a1, a2);
		float t = hash(cell + ivec2(13, 31));
		vec3 c = t < 0.33 ? rock_face : (t < 0.66 ? mix(rock_face, rock_face_light, 0.35) : mix(rock_face, rock_face_dark, 0.4));
		if (above != cell) {
			c = mix(c, rock_face_light, 0.6);
		}
		if (d2 - d1 < 0.8) {
			c = rock_face_dark;
		}
		if (depth <= 1) {
			c = rock_face_light;
		} else if (depth >= face_height - 6) {
			c = mix(c, rock_face_dark, 0.35);
		}
		// Le pied du pan s'assombrit.
		if (below <= 2) {
			c *= 0.75;
		}
		return vec4(c, 1.0);
	}
	// Dessus de la roche, avec un liseré clair là où il borde le sol (nord, est, ouest).
	bool edge = material_at(px + ivec2(0, -1)) != ROCK || material_at(px + ivec2(1, 0)) != ROCK
		|| material_at(px + ivec2(-1, 0)) != ROCK;
	if (edge) {
		return vec4(rock_face_light * 0.8, 1.0);
	}
	int lv = patch_level(px, 91);
	return vec4(lv == 2 ? rock_top_light : rock_top, 1.0);
}

void fragment() {
	ivec2 size = textureSize(types, 0) * tile;
	ivec2 px = ivec2(floor(UV * vec2(size)));
	int m = material_at(px);
	if (m == ROCK) {
		COLOR = rock_color(px);
	} else {
	vec4 col = is_painted(m) ? vec4(painted_color(m, px), 1.0) : tile_pixel(px);
	// Ombre portée au pied des falaises.
	if (material_at(px + ivec2(0, -1)) == ROCK || material_at(px + ivec2(0, -2)) == ROCK) {
		col.rgb *= 0.7;
	}
	int up = material_at(px + ivec2(0, -1));
	int dn = material_at(px + ivec2(0, 1));
	int lf = material_at(px + ivec2(-1, 0));
	int rt = material_at(px + ivec2(1, 0));
	bool touches_green = greenish(up) || greenish(dn) || greenish(lf) || greenish(rt);
	bool touches_water = up == WATER || dn == WATER || lf == WATER || rt == WATER;
	if ((m == DIRT || m == RUBBLE) && touches_green) {
		// Bord de la terre : une ligne plus sombre.
		col.rgb = painted ? rgb(176, 156, 96) : col.rgb * 0.72;
	} else if (m == WATER) {
		if (!touches_water || touches_green || up == DIRT || dn == DIRT || lf == DIRT || rt == DIRT) {
			// Liseré clair au bord de l'eau.
			col.rgb = rgb(214, 228, 222);
		} else {
			int up2 = material_at(px + ivec2(0, -2));
			int up3 = material_at(px + ivec2(0, -3));
			if (up2 != WATER || up3 != WATER) {
				// L'ombre de la berge sur l'eau, côté nord.
				col.rgb *= 0.8;
			}
		}
	} else if (greenish(m) && (dn == DIRT || dn == WATER || dn == RUBBLE || dn == PAVING || dn == SLABS
			|| up == DIRT || lf == DIRT || rt == DIRT)) {
		// Bord de l'herbe : un liseré plus foncé, comme une petite marche.
		col.rgb = m == FOREST ? rgb(58, 84, 46) : rgb(108, 126, 48);
	} else if ((m == PAVING || m == SLABS) && touches_green) {
		col.rgb *= 0.85;
	}
	COLOR = col;
	}
}
