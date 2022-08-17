varying mediump vec2 var_texcoord0;
uniform highp sampler2D tex_downsample;

void main()
{
	lowp vec4 color = texture2D(tex_downsample, var_texcoord0);
	gl_FragColor = color;
}
