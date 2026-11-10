shader_type spatial;
render_mode blend_mix, depth_draw_always, diffuse_toon, specular_toon;

uniform vec4 water_deep : source_color = vec4(0.08, 0.22, 0.12, 0.92);
uniform vec4 water_shallow : source_color = vec4(0.24, 0.55, 0.28, 0.75);
uniform vec4 foam_color : source_color = vec4(0.72, 0.95, 0.62, 0.9);
uniform float wave_speed : hint_range(0.1, 5.0) = 1.2;
uniform float wave_amplitude : hint_range(0.01, 0.2) = 0.04;
uniform float wave_frequency : hint_range(0.5, 10.0) = 3.5;

varying vec3 v_world_pos;

void vertex() {
    v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    
    // Stylized surface ripple oscillation
    float w1 = sin(VERTEX.x * wave_frequency + TIME * wave_speed);
    float w2 = cos(VERTEX.z * (wave_frequency * 1.3) + TIME * (wave_speed * 0.8));
    float combined_wave = (w1 + w2) * 0.5 * wave_amplitude;
    
    VERTEX.y += combined_wave;
    
    // Recalculate normal for cel shading
    NORMAL = normalize(vec3(-cos(VERTEX.x * wave_frequency) * wave_amplitude * 0.5, 1.0, sin(VERTEX.z * wave_frequency) * wave_amplitude * 0.5));
}

void fragment() {
    // Murky toxic shimmer
    float ripple = sin((v_world_pos.x + v_world_pos.z) * 6.0 + TIME * 2.0) * 0.5 + 0.5;
    float ripple2 = cos((v_world_pos.x * 0.8 - v_world_pos.z * 1.2) * 4.0 - TIME * 1.5) * 0.5 + 0.5;
    float blend = clamp((ripple + ripple2) * 0.5, 0.0, 1.0);
    
    vec4 base_color = mix(water_deep, water_shallow, blend);
    
    // Comic edge foam / toxic scum boundary
    float scum = step(0.82, blend);
    vec3 col = mix(base_color.rgb, foam_color.rgb, scum * 0.6);
    
    ALBEDO = col;
    ALPHA = base_color.a;
    ROUGHNESS = 0.15;
    METALLIC = 0.1;
    
    // Eerie toxic green bioluminescent glow
    EMISSION = vec3(0.1, 0.4, 0.15) * 0.4;
}

