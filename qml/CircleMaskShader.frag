#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

uniform sampler2D source;

void main() {
    vec2 coord = qt_TexCoord0 - vec2(0.5);
    float dist = length(coord);
    if (dist > 0.5) {
        fragColor = vec4(0.0, 0.0, 0.0, 0.0);
    } else {
        fragColor = texture(source, qt_TexCoord0);
    }
}
