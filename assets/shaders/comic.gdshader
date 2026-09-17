shader_type spatial;
render_mode unshaded, fog_disabled;

uniform vec4 base_color : source_color = vec4(1.0);
uniform bool use_instance_color = false;
uniform bool full_bright = false;
uniform bool block_lighting = false;
uniform sampler3D light_volume : filter_nearest, repeat_disable;
uniform vec3 light_origin;
uniform vec3 light_extent = vec3(1.0);
uniform float light_step = 0.8;

void fragment() {
    // A fixed drawing convention, independent of scene lights and position.
    vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
    float facing = dot(world_normal, normalize(vec3(-0.6, 0.8, 0.35)));
    float tone = facing > 0.55 ? 1.0 : (facing > -0.15 ? 0.78 : 0.54);
    vec3 pigment = base_color.rgb;
    if (use_instance_color) {
        pigment *= COLOR.rgb;
    }
    // Keep each surface's color fixed as the camera moves. A view-angle rim
    // also darkens grazing floors and walls, producing a moving shadow band.
    vec3 illumination = vec3(1.0);
    if (block_lighting && !full_bright) {
        vec3 world_position = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
        // Read the air just outside the surface, on its side of the wall.
        vec3 uvw = (world_position + world_normal * light_step - light_origin) / light_extent;
        vec2 levels = vec2(1.0, 0.0);
        if (all(greaterThanEqual(uvw, vec3(0.0))) && all(lessThan(uvw, vec3(1.0)))) {
            levels = texture(light_volume, uvw).rg;
        }
        float daylight = 0.22 + 0.70 * levels.r;
        float lamplight = levels.g * levels.g;
        vec3 tint = mix(vec3(0.92, 0.96, 1.0), vec3(1.0, 0.76, 0.45), lamplight * 0.72);
        illumination = tint * max(daylight, 0.22 + lamplight);
    }
    ALBEDO = pigment * (full_bright ? 1.0 : tone) * illumination;
}
