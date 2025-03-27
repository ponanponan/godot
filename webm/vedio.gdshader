shader_type canvas_item;

uniform vec3 key_color : source_color = vec3(0.0, 1.0, 0.0); // 要去的綠色
uniform float threshold : hint_range(0.0, 1.0) = 0.3; // 靈敏度

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    float diff = distance(color.rgb, key_color);

    if (diff < threshold) {
        discard; // 丟棄接近綠色的像素
    }

    COLOR = color;
}
