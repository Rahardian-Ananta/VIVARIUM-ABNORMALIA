shader_type spatial;
render_mode cull_front, unshaded;

uniform vec4 outline_color : source_color = vec4(0.086, 0.071, 0.055, 1.0); // Charcoal ink #16120e
uniform float base_thickness : hint_range(0.005, 0.1) = 0.03;

void vertex() {
    // ModelView vector to determine camera distance
    vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    float dist = length(view_pos.xyz);
    
    // Crisp scale with distance: clamp(distance * 0.008, 0.015, 0.06)
    float outline_width = clamp(dist * 0.008 * (base_thickness / 0.03), 0.015, 0.06);
    VERTEX += NORMAL * outline_width;
}

void fragment() {
    ALBEDO = outline_color.rgb;
    ALPHA = outline_color.a;
}

