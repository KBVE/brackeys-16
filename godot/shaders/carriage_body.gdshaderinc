// &credit -> GodotShaders for some examples and all the other KBVE shaders, damn I have too many.
// &why -> atlas gives 59 texels/m over 697 m2. no atlas size fixes that at web
//         budget, so add high-frequency detail that is independent of it.
// &trick -> UV density is uniform across the whole model, so UV * k lands at a
//           constant PHYSICAL frequency. no triplanar, no UV2, stays tangent space.

uniform sampler2D tex_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_normal : filter_linear_mipmap_anisotropic;
uniform sampler2D tex_mr : filter_linear_mipmap_anisotropic;
uniform sampler2D tex_detail : filter_linear_mipmap_anisotropic, repeat_enable;

uniform float detail_tiling = 45.0;
uniform float detail_strength : hint_range(0.0, 3.0) = 0.55;
uniform float detail_albedo : hint_range(0.0, 0.5) = 0.05;
uniform float detail_rough : hint_range(0.0, 0.3) = 0.07;
uniform float normal_depth : hint_range(0.0, 3.0) = 1.0;

// &cutaway -> SIDE used to slice the near wall with a 10.6m camera near plane,
//             which also clipped the ground under the camera and left a grey
//             band. clipping here instead lets the camera keep a normal near.
uniform float clip_z_above = 1000000.0;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (v_world.z > clip_z_above) {
		discard;
	}

	vec4 alb = texture(tex_albedo, UV);
	vec4 mr = texture(tex_mr, UV);

	vec3 n_base = texture(tex_normal, UV).xyz * 2.0 - 1.0;
	vec3 n_det = texture(tex_detail, UV * detail_tiling).xyz * 2.0 - 1.0;
	// &udn -> keep the base shape, add only the detail slope. cheap and stable
	vec3 n = normalize(vec3(n_base.xy * normal_depth + n_det.xy * detail_strength, n_base.z));

	float grain = (n_det.x + n_det.y) * 0.5;
	ALBEDO = alb.rgb * (1.0 + grain * detail_albedo);
	ROUGHNESS = clamp(mr.g + grain * detail_rough, 0.04, 1.0);
	METALLIC = mr.b;
	NORMAL_MAP = n * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
}
