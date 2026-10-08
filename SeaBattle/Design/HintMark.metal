//
//  HintMark.metal
//  Sea Battle — метка подсказки: латунный блик под водой (07.10)
//
//  `colorEffect` по прямоугольнику размером с клетку: цвет считается целиком
//  здесь, входной не нужен. `size` — сторона клетки в точках, `time` —
//  секунды с появления метки, `tint` — латунь. `reveal` 0…1 — свет
//  растекается от центра при появлении; `gain` — яркость (вспышка при
//  выстреле). Возвращает premultiplied-цвет.
//
//  Каустика — приём «световые жилки на дне»: несколько итераций синусов,
//  вдали от начала координат сумма мала, и светятся только тонкие гребни.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static float caustic(float2 uv, float t) {
    float2 p = uv * 2.5 - 250.0;
    float2 i = p;
    float c = 1.0;
    const float intensity = 0.005;
    for (int n = 0; n < 5; n++) {
        float tt = t * (1.0 - 3.5 / float(n + 1));
        i = p + float2(cos(tt - i.x) + sin(tt + i.y), sin(tt - i.y) + cos(tt + i.x));
        c += 1.0 / length(float2(p.x / (sin(i.x + tt) / intensity),
                                 p.y / (cos(i.y + tt) / intensity)));
    }
    c /= 5.0;
    c = 1.17 - pow(c, 1.4);
    return clamp(pow(abs(c), 8.0), 0.0, 1.0);
}

[[ stitchable ]] half4 hintCaustic(float2 position, half4 color,
                                   float2 size, float time, half4 tint,
                                   float reveal, float gain) {
    // От центра клетки: −1…1 по стороне.
    float2 uv = (position - size * 0.5) / (size.x * 0.5);
    float r = length(uv);
    float light = caustic(uv, time * 0.55);
    // Ярче к центру — «что-то блестит под водой».
    float core = exp(-pow(r / 0.5, 2.0));
    // Мягкий край: к скруглённому краю клетки свет гаснет.
    float edge = 1.0 - smoothstep(0.78, 0.98, max(abs(uv.x), abs(uv.y)));
    // Появление: круг света растёт от центра.
    float front = reveal * 1.5;
    float shown = 1.0 - smoothstep(front - 0.35, front, r);
    float a = clamp((light * (0.6 + 0.8 * core) + core * 0.35) * gain, 0.0, 1.0) * edge * shown;
    return tint * half(a);
}
