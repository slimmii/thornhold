shader_type spatial;
render_mode unshaded, fog_disabled, blend_mix, depth_draw_never;

varying vec2 ground_position;
varying flat vec4 floor_bounds;

void vertex() {
    ground_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
    floor_bounds = INSTANCE_CUSTOM;
}

void fragment() {
    // A small, depth-tested patch on the floor, never a camera-facing effect.
    if (any(lessThan(ground_position, floor_bounds.xy)) ||
            any(greaterThan(ground_position, floor_bounds.zw))) {
        discard;
    }
    vec2 offset = UV * 2.0 - 1.0;
    float softness = 1.0 - smoothstep(0.0, 1.0, dot(offset, offset));
    ALBEDO = vec3(0.0);
    ALPHA = COLOR.a * softness;
}
