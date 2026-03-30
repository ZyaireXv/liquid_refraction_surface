/// 自动雨滴强度档位。
///
/// 这里不去直接暴露一串零散参数，是因为自动雨滴不是包的主功能，
/// 外部更常见的需求是先快速切出“小雨、中雨、大雨”的气质差异。
/// 真要细调数量时，再配合 `rainDropCount` 覆盖默认值就够用了。
enum LiquidRainIntensity { light, medium, heavy }
