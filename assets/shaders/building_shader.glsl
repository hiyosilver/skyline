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

// Output fragment color
out vec4 finalColor;

// We use 'time' to make the noise animated (flicker)
float rand(vec2 co){
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233)) + time) * 43758.5453);
}

void main()
{
    vec2 uv = 0.5 + (fragTexCoord - 0.5)*(0.9 + 0.01*sin(0.5*time));

    vec4 color = texture(texture0, fragTexCoord);

    if(selected) {
        // Calculate luminance (perceived brightness)
        float luminance = dot(color.rgb, vec3(0.299, 0.587, 0.114));

        color = clamp(color*0.5 + 0.5*color*color*1.2, 0.0, 1.0);
        color *= vec4(0.8, 1.0, 0.7, 1);

        // Play with these values!
        float scanlineStrength = 0.08;
        float scanlineSpeed = 2.5;
        float scanlineFrequency = 1000.0;
        
        // The (1.0 - scanlineStrength) part just re-centers the effect
        // This calculation now oscillates between 0.92 and 1.08
        color *= (1.0 - scanlineStrength) + scanlineStrength*sin(scanlineSpeed*time + uv.y*scanlineFrequency);

        // Generate a noise value between -0.5 and 0.5
        float noise = (rand(fragTexCoord) - 0.5); 
        
        // Set how strong the noise is. 0.1 is usually a good, subtle value.
        float noiseStrength = 0.05;
        
        // Apply the noise to the color
        color.rgb += noise * noiseStrength;

        color.rgb = vec3(luminance) * tintColor.rgb;
    }

    if ((selected || hovered) && color.a > 0.5) {
        // Define outline thickness in pixels
        float pixelOffset = 2.0; 
        // Convert pixel offset to UV offset
        vec2 uvOffset = vec2(pixelOffset / textureSize.x, pixelOffset / textureSize.y);

        float a = texture(texture0, vec2(fragTexCoord.x + uvOffset.x, fragTexCoord.y)).a +
                  texture(texture0, vec2(fragTexCoord.x, fragTexCoord.y - uvOffset.y)).a +
                  texture(texture0, vec2(fragTexCoord.x - uvOffset.x, fragTexCoord.y)).a +
                  texture(texture0, vec2(fragTexCoord.x, fragTexCoord.y + uvOffset.y)).a;

        if (a < 3.9) {
            finalColor = vec4(1.0, 1.0, 1.0, 0.8);
            //finalColor.rgb *= tintColor;
        }
        else {
            finalColor = color;
        }
    }
    else {
        finalColor = color;
    }
}