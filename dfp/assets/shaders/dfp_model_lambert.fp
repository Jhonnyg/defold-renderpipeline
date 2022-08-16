varying mediump vec4 var_position;
varying mediump vec4 var_position_world;
varying mediump vec3 var_normal;
varying mediump vec2 var_texcoord0;
varying mediump vec4 var_texcoord0_shadow;
varying mediump vec4 var_light;

uniform lowp sampler2D tex0;
uniform lowp sampler2D tex_depth;

float rgba_to_float(vec4 rgba)
{
    return dot(rgba, vec4(1.0, 1.0/255.0, 1.0/65025.0, 1.0/16581375.0));
}

float get_visibility()
{
    vec4 depth_data        = var_texcoord0_shadow / var_texcoord0_shadow.w;
    const float depth_bias = 0.002;
    // const float depth_bias = 0.00002; // for perspective camera

    float shadow = 0.0;
    vec2 texel_size = 1.0 / textureSize(tex_depth, 0);
    for (int x = -1; x <= 1; ++x)
    {
        for (int y = -1; y <= 1; ++y)
        {
            float depth = rgba_to_float(texture2D(tex_depth, depth_data.st + vec2(x,y) * texel_size));
            shadow += depth_data.z - depth_bias > depth ? 0.8 : 0.0;
        }
    }
    shadow /= 9.0;

    return 1.0 - shadow;
}

vec3 get_light_color()
{
    // Diffuse light calculations
    vec3 ambient_light = vec3(0.2);
    vec3 diff_light    = vec3(normalize(var_light.xyz - var_position.xyz));
    diff_light         = vec3(max(dot(var_normal, diff_light), 0.0)); //  * vec3(249.0/255.0, 255/255.0, 82/255.0);
    diff_light         = diff_light + ambient_light;
    //diff_light         = clamp(diff_light, 0.0, 1.0);
    
    return diff_light;
}

vec3 gamma_correct(vec3 color)
{
    float gamma = 2.2;
    return pow(color.rgb, vec3(1.0/gamma));
}

void main()
{
    vec3 albedo       = texture2D(tex0, var_texcoord0.xy).rgb;
    float occlusion   = get_visibility();
    vec3 light0_color = get_light_color();
    vec3 final_color  = gamma_correct(albedo.rgb * light0_color  * occlusion);
    gl_FragColor      = vec4(final_color, 1.0);
}

