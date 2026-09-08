shader_type canvas_item;

uniform float film_fps : hint_range(8.0, 30.0) = 16.0;
uniform float black_lift : hint_range(0.0, 0.2) = 0.06;
uniform float white_crush : hint_range(0.0, 0.2) = 0.08;
uniform float gate_weave_rotation : hint_range(0.0, 0.05) = 0.015;

uniform float overlay_opacity : hint_range(0.0, 1.0) = 0.546;

uniform float curvature : hint_range(0.0, 0.3) = 0.169;

uniform float scanline_count : hint_range(50.0, 800.0) = 50.0;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.418;
uniform float scanline_speed : hint_range(-10.0, 10.0) = -0.22;

uniform float saturation_boost : hint_range(1.0, 3.0) = 2.167;
uniform float posterize_levels : hint_range(2.0, 32.0) = 32.0;
uniform bool use_posterize = true;

uniform float color_split_base : hint_range(0.0, 0.02) = 0.004;
uniform float color_split_flicker_amount : hint_range(0.0, 0.02) = 0.006;
uniform float color_split_flicker_speed : hint_range(1.0, 30.0) = 10.0;

uniform float vignette_strength : hint_range(0.0, 2.0) = 1.1;
uniform float vignette_softness : hint_range(0.1, 2.0) = 0.913;

uniform float flicker_strength : hint_range(0.0, 0.3) = 0.04;
uniform float flicker_speed : hint_range(1.0, 30.0) = 18.0;
uniform float roll_bar_strength : hint_range(0.0, 0.3) = 0.06;
uniform float roll_bar_speed : hint_range(0.0, 3.0) = 0.18;

uniform bool show_pixel_mask = true;
uniform float pixel_mask_strength : hint_range(0.0, 1.0) = 0.461;
uniform float pixel_mask_size : hint_range(1.0, 8.0) = 3.0;

uniform float bezel_opacity : hint_range(0.0, 1.0) = 1.0;

uniform float grain_strength : hint_range(0.0, 0.5) = 0.12;
uniform float grain_speed : hint_range(1.0, 60.0) = 24.0;

uniform float scratch_strength : hint_range(0.0, 1.0) = 0.3;
uniform float scratch_speed : hint_range(0.5, 10.0) = 3.0;
uniform float scratch_slide_speed : hint_range(0.0, 2.0) = 0.4;

uniform float jitter_strength : hint_range(0.0, 0.01) = 0.003;
uniform float jitter_speed : hint_range(1.0, 30.0) = 3.0;

uniform float faded_tint_amount : hint_range(0.0, 1.0) = 0.35;
uniform vec3 faded_tint_color : source_color = vec3(0.75, 0.65, 0.45);

uniform float particle_strength : hint_range(0.0, 1.0) = 0.2;

uniform float large_speck_strength : hint_range(0.0, 1.0) = 0.3;
uniform float large_speck_size : hint_range(0.001, 0.03) = 0.01;
uniform float large_speck_speed : hint_range(0.2, 10.0) = 1.5;
uniform float large_speck_wobble : hint_range(0.0, 1.0) = 0.5;
uniform int large_speck_count : hint_range(1, 8) = 6;
uniform float large_speck_burst_chance : hint_range(0.0, 1.0) = 0.4;
uniform int large_speck_wave_count : hint_range(1, 4) = 2;
uniform float blotch_strength : hint_range(0.0, 0.5) = 0.15;
uniform float blotch_size : hint_range(0.02, 0.3) = 0.12;
uniform int blotch_count : hint_range(1, 6) = 3;
uniform float blotch_drift_speed : hint_range(0.0, 0.1) = 0.02;


uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

vec2 curve_uv(vec2 uv) {
	uv = uv * 2.0 - 1.0;
	vec2 offset = abs(uv.yx) / vec2(1.0 / curvature, 1.0 / curvature);
	uv = uv + uv * offset * offset;
	uv = uv * 0.5 + 0.5;
	return uv;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float film_time = floor(TIME * film_fps) / film_fps;
	float jitter_time = floor(film_time * jitter_speed);
	vec2 jitter = vec2(
		hash(vec2(jitter_time, 0.0)) - 0.5,
		hash(vec2(jitter_time, 1.0)) - 0.5
	) * jitter_strength;
	
	vec2 uv = curve_uv(SCREEN_UV + jitter);
	
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, bezel_opacity);
	} else {
		float split_time_step = floor(TIME * color_split_flicker_speed);
		float split_noise = hash(vec2(split_time_step, 3.0));
		float split = color_split_base + split_noise * color_split_flicker_amount;
		
		float r = texture(SCREEN_TEXTURE, uv + vec2(split, 0.0)).r;
		float g = texture(SCREEN_TEXTURE, uv).g;
		float b = texture(SCREEN_TEXTURE, uv - vec2(split, 0.0)).b;
		vec3 col = vec3(r, g, b);
		
		float luma = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(vec3(luma), col, saturation_boost);
		
		if (use_posterize) {
			col = floor(col * posterize_levels) / posterize_levels;
		}
		
		vec3 tinted_color = vec3(dot(col, vec3(0.299, 0.587, 0.114))) * faded_tint_color;
		col = mix(col, tinted_color, faded_tint_amount);
		
		float scan_uv_y = uv.y + TIME * scanline_speed * 0.05;
		float scanline = sin(scan_uv_y * scanline_count * PI) * 0.5 + 0.5;
		col *= mix(1.0, scanline, scanline_strength);
		
		if (show_pixel_mask) {
			float mask_x = mod(uv.x / SCREEN_PIXEL_SIZE.x, pixel_mask_size * 3.0);
			vec3 mask_col = vec3(0.0);
			if (mask_x < pixel_mask_size) mask_col.r = 1.0;
			else if (mask_x < pixel_mask_size * 2.0) mask_col.g = 1.0;
			else mask_col.b = 1.0;
			col = mix(col, col * (mask_col + 0.5), pixel_mask_strength);
		}
		
		vec2 vig_uv = uv * (1.0 - uv.yx);
		float vig = vig_uv.x * vig_uv.y * 15.0;
		vig = pow(vig, vignette_strength * (1.0 / vignette_softness));
		col *= clamp(vig, 0.0, 1.0);
		
		float flicker_a = sin(TIME * flicker_speed) * 0.5 + 0.5;
		float flicker_b = hash(vec2(floor(TIME * flicker_speed * 2.0), 0.0));
		float flicker = mix(flicker_a, flicker_b, 0.5);
		col *= 1.0 - (flicker * flicker_strength);
		
		float roll = fract(uv.y - TIME * roll_bar_speed);
		float bar = smoothstep(0.0, 0.02, roll) * smoothstep(0.08, 0.02, roll);
		col += bar * roll_bar_strength;
		
		float grain_time = floor(TIME * grain_speed);
		float grain = hash(uv * SCREEN_PIXEL_SIZE.x * 500.0 + grain_time) - 0.5;
		col += grain * grain_strength;
		
		for (int i = 0; i < 3; i++) {
			float scratch_seed = float(i) * 11.0;
			float scratch_step_id = floor((TIME + scratch_seed * 3.7) * scratch_speed);
			float scratch_progress = fract((TIME + scratch_seed * 3.7) * scratch_speed);

			float scratch_start_x = hash(vec2(scratch_step_id, 5.0 + scratch_seed));
			float scratch_direction = hash(vec2(scratch_step_id, 21.0 + scratch_seed)) > 0.5 ? 1.0 : -1.0;
			float scratch_x = scratch_start_x + scratch_direction * scratch_slide_speed * scratch_progress;

			float scratch_dist = abs(uv.x - scratch_x);
			float scratch_line = smoothstep(0.0015, 0.0, scratch_dist);
			float scratch_visible = step(0.6, hash(vec2(scratch_step_id, 9.0 + scratch_seed)));
			float scratch_fade = 1.0 - smoothstep(0.8, 1.0, scratch_progress);

			col += scratch_line * scratch_visible * scratch_fade * scratch_strength;
		}
		
		float speck_burst_id = floor(TIME * large_speck_speed);
		float speck_burst_progress = fract(TIME * large_speck_speed);
		float speck_burst_active = step(1.0 - large_speck_burst_chance, hash(vec2(speck_burst_id, 100.0)));
		float speck_burst_fade = 1.0 - smoothstep(0.0, 0.7, speck_burst_progress);
		for (int w = 0; w < large_speck_wave_count; w++) {
			float wave_offset = (1.0 / float(large_speck_wave_count)) * float(w);
			float wave_time = TIME * large_speck_speed + wave_offset;

			float speck_burst_id = floor(wave_time);
			float speck_burst_progress = fract(wave_time);
			float speck_burst_active = step(1.0 - large_speck_burst_chance, hash(vec2(speck_burst_id, 100.0 + float(w) * 500.0)));
			float speck_burst_fade = 1.0 - smoothstep(0.0, 0.7, speck_burst_progress);

			for (int i = 0; i < large_speck_count; i++) {
				float speck_seed = float(i) * 17.0 + float(w) * 313.0;

				float speck_active = step(0.4, hash(vec2(speck_burst_id, 200.0 + speck_seed)));
				if (speck_active < 0.5) {
					continue;
				}

				vec2 speck_pos = vec2(
					hash(vec2(speck_burst_id, 31.0 + speck_seed)),
					hash(vec2(speck_burst_id, 47.0 + speck_seed))
				);
				float speck_radius = large_speck_size * (0.6 + hash(vec2(speck_burst_id, 63.0 + speck_seed)) * 1.2);
				float speck_phase = hash(vec2(speck_burst_id, 71.0 + speck_seed)) * TAU;

				vec2 speck_diff = uv - speck_pos;
				float speck_angle = atan(speck_diff.y, speck_diff.x);
				float wobble = 1.0 + large_speck_wobble * sin(speck_angle * 3.0 + speck_phase) * 0.5
					+ large_speck_wobble * sin(speck_angle * 5.0 + speck_phase * 1.7) * 0.3;

				float speck_dist = length(speck_diff);
				float speck_shape = smoothstep(speck_radius * wobble, speck_radius * wobble * 0.3, speck_dist);

				col += speck_shape * speck_burst_active * speck_burst_fade * large_speck_strength;
			}
		}
		
		for (int b = 0; b < blotch_count; b++) {
			float blotch_seed = float(b) * 41.0;
			vec2 blotch_base = vec2(
				hash(vec2(blotch_seed, 1.0)),
				hash(vec2(blotch_seed, 2.0))
			);
			vec2 blotch_drift = vec2(
				sin(film_time * blotch_drift_speed + blotch_seed) ,
				cos(film_time * blotch_drift_speed * 0.7 + blotch_seed)
			) * 0.03;
			vec2 blotch_pos = blotch_base + blotch_drift;

			float blotch_dist = length(uv - blotch_pos);
			float blotch_shape = smoothstep(blotch_size, blotch_size * 0.2, blotch_dist);

			col -= blotch_shape * blotch_strength;
		}
		
		float particle_time = floor(TIME * grain_speed);
		float particle_noise = hash(uv * 80.0 + particle_time);
		float particle = step(0.997, particle_noise) * particle_strength;
		col += particle;
		
		COLOR = vec4(col, overlay_opacity);
	}
}