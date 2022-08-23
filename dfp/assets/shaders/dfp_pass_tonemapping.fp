varying mediump vec2 var_texcoord0;
uniform highp sampler2D tex_lighting;
uniform lowp vec4 exposure;

vec3 tonemapping_reinhard(vec3 color)
{
	const float gamma = 2.2;
	// reinhard tone mapping
	vec3 mapped = vec3(1.0) - exp(-color * exposure.r);
	// gamma correction 
	return pow(mapped, vec3(1.0 / gamma));
}

void main()
{
	vec4 lighting_sample     = texture2D(tex_lighting, var_texcoord0);
	vec3 lighting_tonemapped = tonemapping_reinhard(lighting_sample.rgb);
	gl_FragColor             = vec4(lighting_tonemapped, lighting_sample.a);
}
