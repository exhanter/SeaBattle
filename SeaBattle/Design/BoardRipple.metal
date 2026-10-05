//
//  BoardRipple.metal
//  Sea Battle — волны по полю (05.10)
//
//  `boardRipple` — волна от клетки выстрела: каждая точка смещается вдоль
//  луча от клетки. Волна доходит до точки через `distance / speed` секунд,
//  там качается синусом и затухает по времени (`decay`) и по расстоянию
//  (`falloff`), а за `radius` гаснет совсем — волна не уходит дальше соседних
//  клеток (05.10). Гребень чуть светлее.
//
//  `boardSweep` — финал партии: по полю наискось проходит световой вал.
//  Фронт — прямая, перпендикулярная `direction`, стоит на `front` (в точках
//  вдоль `direction`). Внутри вала поле качается волной вдоль направления и
//  светлеет; вне вала — нетронуто.
//
//  Свифтовая сторона — `BoardRippleModifier` и `BoardSweepModifier` в
//  `CellEffects.swift`.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] half4 boardRipple(float2 position, SwiftUI::Layer layer,
                                   float2 origin, float time,
                                   float amplitude, float frequency,
                                   float decay, float speed, float falloff,
                                   float radius) {
    float2 delta = position - origin;
    float distance = length(delta);
    if (distance < 0.001 || distance > radius) {
        return layer.sample(position);
    }
    float arrival = distance / speed;
    // До прихода волны точка стоит на месте.
    if (time < arrival) {
        return layer.sample(position);
    }
    float local = time - arrival;
    float wave = sin(frequency * local) * exp(-decay * local) * exp(-distance / falloff)
        * (1.0 - smoothstep(radius * 0.55, radius, distance));
    float2 shifted = position + amplitude * wave * (delta / distance);
    half4 color = layer.sample(shifted);
    color.rgb += half(0.10 * wave) * color.a;
    return color;
}

[[ stitchable ]] half4 boardSweep(float2 position, SwiftUI::Layer layer,
                                  float2 direction, float front, float width,
                                  float amplitude, float wavelength, float glow) {
    float along = dot(position, direction) - front;
    // Огибающая вала: гауссиана шириной `width` вокруг фронта.
    float envelope = exp(-(along * along) / (width * width));
    if (envelope < 0.002) {
        return layer.sample(position);
    }
    float phase = 6.2831853 * along / wavelength;
    float2 shifted = position + direction * (amplitude * envelope * sin(phase));
    half4 color = layer.sample(shifted);
    float light = glow * envelope * (0.65 + 0.35 * cos(phase));
    color.rgb += half(light) * color.a;
    return color;
}
