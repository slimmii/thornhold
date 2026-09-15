shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform vec4 gate_color : source_color = vec4(0.15, 1.0, 0.57, 1.0);
void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    float radius = length(p);
    float angle = atan(p.y, p.x);
    float spiral = sin(radius * 23.0 - TIME * 2.8 + angle * 3.0);
    float ripples = sin(p.y * 26.0 + TIME * 2.0 + sin(p.x * 15.0));
    float edge = 1.0 - smoothstep(0.72, 1.0, radius);
    float heart = 0.3 + 0.35 * spiral + 0.14 * ripples;
    ALBEDO = gate_color.rgb * (0.6 + heart);
    ALPHA = edge * (0.48 + heart * 0.42);
}
