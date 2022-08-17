varying mediump vec2 var_texcoord0;
uniform highp sampler2D tex_lighting;
uniform highp vec4 tex_resolution;

// Note: This code is directly taken (and slightly modified) from https://learnopengl.com/Guest-Articles/2022/Phys.-Based-Bloom
//       All credit goes to that author (Jorge Jimenez)!
vec3 get_downsampled_color(sampler2D srcTexture, vec2 srcResolution, vec2 texCoord)
{
	vec2 srcTexelSize = 1.0 / srcResolution;
	float x = srcTexelSize.x;
	float y = srcTexelSize.y;

	// Take 13 samples around current texel:
	// a - b - c
	// - j - k -
	// d - e - f
	// - l - m -
	// g - h - i
	// === ('e' is the current texel) ===
	vec3 a = texture2D(srcTexture, vec2(texCoord.x - 2*x, texCoord.y + 2*y)).rgb;
	vec3 b = texture2D(srcTexture, vec2(texCoord.x,       texCoord.y + 2*y)).rgb;
	vec3 c = texture2D(srcTexture, vec2(texCoord.x + 2*x, texCoord.y + 2*y)).rgb;

	vec3 d = texture2D(srcTexture, vec2(texCoord.x - 2*x, texCoord.y)).rgb;
	vec3 e = texture2D(srcTexture, vec2(texCoord.x,       texCoord.y)).rgb;
	vec3 f = texture2D(srcTexture, vec2(texCoord.x + 2*x, texCoord.y)).rgb;

	vec3 g = texture2D(srcTexture, vec2(texCoord.x - 2*x, texCoord.y - 2*y)).rgb;
	vec3 h = texture2D(srcTexture, vec2(texCoord.x,       texCoord.y - 2*y)).rgb;
	vec3 i = texture2D(srcTexture, vec2(texCoord.x + 2*x, texCoord.y - 2*y)).rgb;

	vec3 j = texture2D(srcTexture, vec2(texCoord.x - x, texCoord.y + y)).rgb;
	vec3 k = texture2D(srcTexture, vec2(texCoord.x + x, texCoord.y + y)).rgb;
	vec3 l = texture2D(srcTexture, vec2(texCoord.x - x, texCoord.y - y)).rgb;
	vec3 m = texture2D(srcTexture, vec2(texCoord.x + x, texCoord.y - y)).rgb;

	// Apply weighted distribution:
	// 0.5 + 0.125 + 0.125 + 0.125 + 0.125 = 1
	// a,b,d,e * 0.125
	// b,c,e,f * 0.125
	// d,e,g,h * 0.125
	// e,f,h,i * 0.125
	// j,k,l,m * 0.5
	// This shows 5 square areas that are being sampled. But some of them overlap,
	// so to have an energy preserving downsample we need to make some adjustments.
	// The weights are the distributed, so that the sum of j,k,l,m (e.g.)
	// contribute 0.5 to the final color output. The code below is written
	// to effectively yield this sum. We get:
	// 0.125*5 + 0.03125*4 + 0.0625*4 = 1
	vec3 downsample = e*0.125;
	downsample += (a+c+g+i)*0.03125;
	downsample += (b+d+f+h)*0.0625;
	downsample += (j+k+l+m)*0.125;
	return downsample;
}

void main()
{
	lowp vec3 color = get_downsampled_color(tex_lighting, tex_resolution.st, var_texcoord0);
	gl_FragColor = vec4(color, 1.0);
}
