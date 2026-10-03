#version 300 es
precision mediump float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

void main() {
    vec4 color = texture(tex, v_texcoord);

    // Мягкий тёплый оттенок (как у классического Night Light в Android)
    vec3 nightColor = vec3(1.0, 0.78, 0.55);

    // Интенсивность фильтра (0.35 — оптимальный баланс для комфорта глаз)
    float intensity = 0.35;

    // Плавное наложение тёплого тона
    vec3 filtered = mix(color.rgb, color.rgb * nightColor, intensity);

    fragColor = vec4(filtered, color.a);
}
