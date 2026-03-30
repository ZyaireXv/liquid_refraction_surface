#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform float uDisplacementScale;
uniform float uHighlightOpacity;
uniform float uChromaticAberration;
uniform float uMetalness;
uniform float uRoughness;
uniform sampler2D uTexture;
uniform sampler2D uField;

out vec4 fragColor;

vec2 safeUv(vec2 uv) {
  return clamp(uv, vec2(0.001), vec2(0.999));
}

vec2 toTextureUv(vec2 screenUv) {
  vec2 textureUv = screenUv;

#ifdef IMPELLER_TARGET_OPENGLES
  // Android 侧常见的是 OpenGLES 管线，采样坐标和屏幕坐标在 Y 轴上的朝向并不一致。
  // 这里统一先把“屏幕空间坐标”换成“纹理采样坐标”，后面的上下左右邻域采样都继续基于屏幕语义，
  // 这样一来法线推导和折射偏移就不会因为平台差异而整体反向。
  textureUv.y = 1.0 - textureUv.y;
#endif

  return safeUv(textureUv);
}

vec4 sampleField(vec2 screenUv) {
  return texture(uField, toTextureUv(screenUv));
}

vec4 sampleScene(vec2 screenUv) {
  return texture(uTexture, toTextureUv(screenUv));
}

vec2 decodeNormal(vec4 fieldSample) {
  return (fieldSample.xy * 2.0) - 1.0;
}

float decodeHeight(vec4 fieldSample) {
  return (fieldSample.a * 2.0) - 1.0;
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = fragCoord / uSize;
  vec2 texel = 1.0 / uSize;

  vec4 field = sampleField(uv);
  vec4 fieldLeft = sampleField(uv - vec2(texel.x, 0.0));
  vec4 fieldRight = sampleField(uv + vec2(texel.x, 0.0));
  vec4 fieldTop = sampleField(uv - vec2(0.0, texel.y));
  vec4 fieldBottom = sampleField(uv + vec2(0.0, texel.y));

  vec2 encodedNormal = decodeNormal(field);
  float motion = field.z;
  float height = decodeHeight(field);
  float heightGradientX = decodeHeight(fieldRight) - decodeHeight(fieldLeft);
  float heightGradientY = decodeHeight(fieldBottom) - decodeHeight(fieldTop);
  vec2 heightNormal = vec2(heightGradientX, heightGradientY) * 0.5;
  vec2 normal = mix(encodedNormal, encodedNormal + heightNormal, 0.58);

  float thickness = smoothstep(0.02, 0.38, abs(height));
  float motionMask = smoothstep(0.015, 0.18, motion);
  float surfaceEnergy = clamp((length(normal) * 0.95) + (abs(height) * 0.45), 0.0, 1.0);
  float energyMask = smoothstep(0.035, 0.24, surfaceEnergy);
  float displacement = uDisplacementScale * (0.0072 + (thickness * 0.0048) + (motionMask * 0.0032) + (uMetalness * 0.0012));
  vec2 offset = normal * displacement;
  vec2 innerOffset = normal * displacement * (0.36 + (thickness * 0.14));

  float chromatic = uChromaticAberration * 0.0032 * (energyMask * 0.65 + motionMask * 0.35);
  float shimmer = sin((uv.y * 22.0) + (uTime * 2.2)) * 0.5 + 0.5;
  vec2 shimmerOffset = normal * shimmer * 0.0018 * (1.0 - (uRoughness * 0.35));
  vec2 tangent = normalize(vec2(normal.y + 0.0001, -normal.x + 0.0001));
  vec2 chromaticOffset = tangent * chromatic;

  vec4 outerSampleR = sampleScene(uv + offset + shimmerOffset + chromaticOffset);
  vec4 outerSampleG = sampleScene(uv + offset + (shimmerOffset * 0.75));
  vec4 outerSampleB = sampleScene(uv + offset + shimmerOffset - chromaticOffset);
  vec4 innerSample = sampleScene(uv + innerOffset);

  vec3 outerColor = vec3(
    outerSampleR.r,
    outerSampleG.g,
    outerSampleB.b
  );
  vec3 innerColor = innerSample.rgb;
  vec3 color = mix(outerColor, innerColor, 0.08 + (thickness * 0.14));

  float highlight = smoothstep(0.04, 0.3, surfaceEnergy);
  float rim = max(0.0, dot(normalize(vec2(-0.45, -0.8)), normalize(vec2(-normal.x, 1.0 - abs(normal.y)))));
  float fresnel = pow(clamp(1.0 - dot(normalize(vec3(normal * 1.25, 1.0)), vec3(0.0, 0.0, 1.0)), 0.0, 1.0), 2.2);
  float crest = smoothstep(0.06, 0.28, height);
  float trough = smoothstep(0.06, 0.3, -height);
  float glintBand = pow(1.0 - abs(dot(tangent, normalize(vec2(0.9, 0.36)))), 6.0);
  float motionGlint = motionMask * glintBand * (0.35 + (shimmer * 0.65));
  vec3 highlightColor = mix(
    vec3(0.78, 0.88, 1.0),
    vec3(0.94, 0.98, 1.0),
    0.48 + (uMetalness * 0.18)
  );
  vec3 glintColor = mix(
    vec3(0.85, 0.94, 1.0),
    vec3(1.0),
    0.35 + (motionMask * 0.45)
  );
  color += highlightColor * highlight * rim * uHighlightOpacity * 1.08;
  color += highlightColor * fresnel * energyMask * uHighlightOpacity * (0.42 + (uMetalness * 0.34));
  color += glintColor * motionGlint * uHighlightOpacity * (0.9 + (uMetalness * 0.22));
  color += vec3(0.96, 0.99, 1.0) * crest * uHighlightOpacity * 0.18;

  float surfaceWash = 0.006 + (uMetalness * 0.016);
  color += vec3(0.9, 0.96, 1.0) * surfaceWash * (0.72 + (shimmer * 0.28));
  color -= vec3(0.018, 0.02, 0.024) * trough * (0.42 + (thickness * 0.28));
  color = mix(color, color * 0.992, uRoughness * 0.08);
  color = clamp(color, 0.0, 1.0);

  fragColor = vec4(color, 1.0);
}
