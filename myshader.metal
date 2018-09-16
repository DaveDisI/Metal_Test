#include <metal_stdlib>
using namespace metal;

vertex float4
vertexShader(uint vertexID [[vertex_id]], constant float4 *vertices){
    return vertices[vertexID];
}

fragment float4 fragmentShader(){
    return float4(1, 0, 0, 1);
}