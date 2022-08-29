varying mediump vec2 var_texcoord0;
uniform highp sampler2D tex_downsample;
uniform highp sampler2D tex_lighting;
uniform lowp vec4 u_bloom_params;

void main()
{
	float bloom_strength 	   = u_bloom_params.y;
	lowp vec4 color_downsample = texture2D(tex_downsample, var_texcoord0);
	lowp vec4 color_sample     = texture2D(tex_lighting, var_texcoord0);
	lowp vec4 color_composite  = mix(color_sample, color_downsample, bloom_strength);
	
	gl_FragColor = vec4(color_composite.rgb,1.0);

	gl_FragColor = vec4(1.0);
}
