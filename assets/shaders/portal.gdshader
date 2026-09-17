shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform vec4 gate_color : source_color = vec4(0.16, 0.72, 0.53, 1.0);
void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    // Opaque nested diamonds replace the additive animated glow.
    float diamond = abs(p.x) + abs(p.y);
    float band = diamond < 0.32 ? 1.0 : (diamond < 0.65 ? 0.66 : 0.32);
    float ink = step(0.035, min(abs(diamond - 0.32), abs(diamond - 0.65)));
    ALBEDO = gate_color.rgb * band * mix(0.2, 1.0, ink);
}
