#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;

uniform vec2 textureSize;
uniform float time;
uniform vec3 tintColor;
uniform bool hovered;
uniform bool selected;

out vec4 finalColor;

float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233)) + time) * 43758.5453);
}

void main() {
    vec2 uv = 0.5 + (fragTexCoord - 0.5)*(0.9 + 0.01*sin(0.5*time));

    vec4 color = texture(texture0, fragTexCoord);

    if(selected) {
        float luminance = dot(color.rgb, vec3(0.299, 0.587, 0.114));

        color = clamp(color*0.5 + 0.5*color*color*1.2, 0.0, 1.0);
        color *= vec4(0.8, 1.0, 0.7, 1);

        float scanlineStrength = 0.08;
        float scanlineSpeed = 2.5;
        float lineThicknessInPixels = 1.0;

        float scanlineFrequency = textureSize.y / lineThicknessInPixels;
        
        color *= (1.0 - scanlineStrength) + scanlineStrength*sin(scanlineSpeed*time + uv.y*scanlineFrequency);

        float noise = (rand(fragTexCoord) - 0.5); 
        
        float noiseStrength = 0.05;
        
        color.rgb += noise * noiseStrength;

        color.rgb = mix(vec3(luminance), tintColor.rgb, 0.25);
    }

    if ((selected || hovered) && color.a > 0.5) {
        float pixelOffset = 2.0;
        vec2 uvOffset = vec2(pixelOffset / textureSize.x, pixelOffset / textureSize.y);

        float a = texture(texture0, vec2(fragTexCoord.x + uvOffset.x, fragTexCoord.y)).a +
                  texture(texture0, vec2(fragTexCoord.x, fragTexCoord.y - uvOffset.y)).a +
                  texture(texture0, vec2(fragTexCoord.x - uvOffset.x, fragTexCoord.y)).a +
                  texture(texture0, vec2(fragTexCoord.x, fragTexCoord.y + uvOffset.y)).a;

        if (a < 3.9) {
            finalColor = vec4(1.0, 1.0, 1.0, 0.8);
        }
        else {
            finalColor = color;
        }
    }
    else {
        finalColor = color;
    }
}