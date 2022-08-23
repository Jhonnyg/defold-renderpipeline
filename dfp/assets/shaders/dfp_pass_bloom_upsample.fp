varying mediump vec2 	var_texcoord0;	
uniform highp sampler2D tex_downsampled;
uniform lowp vec4 	 	u_bloom_params;

// Note: This code is directly taken (and slightly modified) from https://learnopengl.com/Guest-Articles/2022/Phys.-Based-Bloom
//       All credit goes to that author (Jorge Jimenez)!
vec3 get_upsampled_color(sampler2D srcTexture, float filterRadius, vec2 texCoord)
{
	vec3 upsample = vec3(0.0);
	// The filter kernel is applied with a radius, specified in texture
	// coordinates, so that the radius will vary across mip resolutions.
	float x = filterRadius;
	float y = filterRadius;

	// Take 9 samples around current texel:
	// a - b - c
	// d - e - f
	// g - h - i
	// === ('e' is the current texel) ===
	vec3 a = texture(srcTexture, vec2(texCoord.x - x, texCoord.y + y)).rgb;
	vec3 b = texture(srcTexture, vec2(texCoord.x,     texCoord.y + y)).rgb;
	vec3 c = texture(srcTexture, vec2(texCoord.x + x, texCoord.y + y)).rgb;

	vec3 d = texture(srcTexture, vec2(texCoord.x - x, texCoord.y)).rgb;
	vec3 e = texture(srcTexture, vec2(texCoord.x,     texCoord.y)).rgb;
	vec3 f = texture(srcTexture, vec2(texCoord.x + x, texCoord.y)).rgb;

	vec3 g = texture(srcTexture, vec2(texCoord.x - x, texCoord.y - y)).rgb;
	vec3 h = texture(srcTexture, vec2(texCoord.x,     texCoord.y - y)).rgb;
	vec3 i = texture(srcTexture, vec2(texCoord.x + x, texCoord.y - y)).rgb;

	// Apply weighted distribution, by using a 3x3 tent filter:
	//  1   | 1 2 1 |
	// -- * | 2 4 2 |
	// 16   | 1 2 1 |
	upsample = e*4.0;
	upsample += (b+d+f+h)*2.0;
	upsample += (a+c+g+i);
	upsample *= 1.0 / 16.0;
	return upsample;
}

void main()
{
	vec3 color = get_upsampled_color(tex_downsampled, u_bloom_params.x, var_texcoord0.st);
	gl_FragColor = vec4(color, 1.0);
}
