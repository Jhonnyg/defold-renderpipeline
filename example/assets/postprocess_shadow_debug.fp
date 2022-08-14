varying mediump vec2 var_texcoord0;
uniform lowp sampler2D texture_sampler;

void main()
{
    float depth = texture2D(texture_sampler, var_texcoord0.xy).r;
    gl_FragColor = vec4(vec3(depth), 1.0);
}
