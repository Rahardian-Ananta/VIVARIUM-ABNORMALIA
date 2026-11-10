shader_type spatial;
render_mode blend_mix, depth_draw_always, diffuse_toon, specular_toon, cull_disabled;

uniform vec4 glass_tint : source_color = vec4(0.85, 0.95, 0.98, 0.15);
uniform vec4 rim_tint : source_color = vec4(0.65, 0.85, 0.95, 0.65);
uniform vec3 tap_world_pos = vec3(0.0, 0.0, 0.0);
uniform float tap_elapsed = 999.0;
uniform float shockwave_speed = 6.0;
uniform float shockwave_width = 0.4;
uniform float shockwave_intensity = 0.0;

varying vec3 v_world_pos;

void vertex() {
    v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    // Distance from glass tap shockwave point
    float d = distance(v_world_pos, tap_world_pos);
    float wave_dist = tap_elapsed * shockwave_speed;
    
    // Concentric shockwave ring calculation
    float ring = 0.0;
    if (shockwave_intensity > 0.001 && tap_elapsed < 2.0) {
        float ring_delta = abs(d - wave_dist);
        float ring_mask = smoothstep(shockwave_width, 0.0, ring_delta);
        // Multi-ring ripple modulation
        float ripples = sin((d - wave_dist) * 20.0) * 0.5 + 0.5;
        // Fade out with time and distance
        float decay = exp(-tap_elapsed * 2.5) * clamp(1.0 - (d / 12.0), 0.0, 1.0);
        ring = ring_mask * ripples * decay * shockwave_intensity;
    }
    
    // Glass Fresnel rim
    float fresnel = pow(clamp(1.0 - dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
    
    vec3 col = glass_tint.rgb + ring * vec3(0.9, 0.95, 1.0) * 2.0;
    float alpha = clamp(glass_tint.a + fresnel * rim_tint.a + ring * 0.7, 0.0, 0.85);
    
    ALBEDO = col;
    ALPHA = alpha;
    ROUGHNESS = 0.1;
    METALLIC = 0.05;
    EMISSION = ring * vec3(0.8, 0.92, 1.0) * 1.5;
}

