#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Eight-point alignment: bends the already-perspective-mapped wall so each tapestry edge can bow
// through its midpoint (Calibration.bend). For each screen pixel: find the artwork point it shows
// (inverse homography rows h0..h2), compute the bend there, and sample from where that light
// should have come from. Offsets are small (≤ 8% of the frame), so one step is enough.
//   tb = (top.x, top.y, bottom.x, bottom.y), rl = (right.x, right.y, left.x, left.y)  — normalized
[[ stitchable ]] float2 wildernessBend(float2 position, float3 h0, float3 h1, float3 h2,
                                       float2 screen, float4 tb, float4 rl) {
    float3 p = float3(position, 1.0);
    float w = dot(h2, p);
    float u = clamp(dot(h0, p) / w, 0.0, 1.0);
    float v = clamp(dot(h1, p) / w, 0.0, 1.0);
    float bu = 4.0 * u * (1.0 - u);
    float bv = 4.0 * v * (1.0 - v);
    float2 d = (1.0 - v) * tb.xy * bu + v * tb.zw * bu + (1.0 - u) * rl.zw * bv + u * rl.xy * bv;
    return position - d * screen;
}
