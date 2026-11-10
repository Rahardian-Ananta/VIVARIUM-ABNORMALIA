shader_type spatial;
render_mode blend_mix, depth_draw_opaque, diffuse_toon, specular_toon;

uniform vec4 albedo_color : source_color = vec4(0.85, 0.76, 0.62, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.12, 0.18, 0.22, 1.0);
uniform vec3 heat_lamp_rim : source_color = vec3(1.0, 0.62, 0.267); // #ff9e44 Warm Amber
uniform vec3 biolume_cyan_rim : source_color = vec3(0.2, 1.0, 0.8);  // #33ffcc Eerie Cyan
uniform float rot_factor : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.45;
uniform float metallic : hint_range(0.0, 1.0) = 0.05;
uniform float fever_glow : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_world_pos;
varying vec3 v_world_normal;

// Simple procedural hash for chitin mottling & rot spots (GLES3 / WebGL compatible)
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
    v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
    // Chitin pattern & necrotic rot spots
    vec2 uv_noise = v_world_pos.xz * 4.5 + v_world_pos.y * 3.0;
    float n = noise(uv_noise);
    float n2 = noise(uv_noise * 2.8 + vec2(1.7, 9.2));
    
    // Base albedo with organic chitin mottling
    vec3 base = albedo_color.rgb * mix(0.85, 1.15, n);
    
    // Necrotic rot spots based on rot_factor
    float rot_mask = smoothstep(1.0 - rot_factor * 0.9, 1.0, n2);
    vec3 rot_color = vec3(0.18, 0.22, 0.08) * 0.7; // sickly greenish necrotic
    vec3 final_albedo = mix(base, rot_color, rot_mask * rot_factor);
    
    // Feverish starvation red pulse
    if (fever_glow > 0.0) {
        float pulse = 0.5 + 0.5 * sin(TIME * 8.0);
        final_albedo = mix(final_albedo, vec3(0.9, 0.1, 0.05), fever_glow * pulse * 0.6);
    }
    
    ALBEDO = final_albedo;
    ROUGHNESS = roughness;
    METALLIC = metallic;
    
    // Rim lighting (Fresnel)
    float fresnel = pow(clamp(1.0 - dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
    // Blend between warm amber (higher canopy Y) and bioluminescent cyan (lower/darker sump Y)
    float height_t = clamp((v_world_pos.y - 0.5) / 4.5, 0.0, 1.0);
    vec3 rim_color = mix(biolume_cyan_rim, heat_lamp_rim, height_t);
    
    if (fever_glow > 0.0) {
        rim_color = mix(rim_color, vec3(1.0, 0.1, 0.1), fever_glow);
    }
    
    EMISSION = rim_color * fresnel * 0.85;
}

void light() {
    // Stepped 3-band toon lighting ramp
    float NdotL = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
    
    // Band 1: Deep shadow to midtone (tight threshold 0.05)
    float step1 = smoothstep(0.04, 0.06, NdotL);
    // Band 2: Midtone to full highlight (tight threshold 0.55)
    float step2 = smoothstep(0.53, 0.57, NdotL);
    
    float toon_intensity = mix(0.25, 0.65, step1);
    toon_intensity = mix(toon_intensity, 1.0, step2);
    
    // Shadow color tint for comic diorama feel
    vec3 light_result = mix(shadow_tint.rgb, LIGHT_COLOR.rgb, toon_intensity) * ATTENUATION;
    DIFFUSE_LIGHT += ALBEDO * light_result;
}

