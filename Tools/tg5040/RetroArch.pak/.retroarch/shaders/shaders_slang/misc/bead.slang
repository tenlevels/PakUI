#version 450

/*
   Author: Themaister
   License: Public domain
*/

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
   float BEAD_HIGH, BEAD_LOW;
} params;

#pragma parameter BEAD_HIGH "Bead High" 0.35 0.0 1.0 0.01
#define BEAD_HIGH params.BEAD_HIGH
#pragma parameter BEAD_LOW  "Bead Low"  0.2  0.0 1.0 0.01
#define BEAD_LOW params.BEAD_LOW

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 pixel_no;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
   pixel_no = vTexCoord * params.SourceSize.xy;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 pixel_no;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

float dist(vec2 coord, vec2 source)
{
   vec2 delta = coord - source;
   return sqrt(dot(delta, delta));
}

float rolloff(float len)
{
   return exp(-6.0 * len);
}

vec3 lookup(vec2 pixel_no, vec3 color)
{
   float delta = dist(fract(pixel_no), vec2(0.5, 0.5));

   if (delta > BEAD_LOW && delta < BEAD_HIGH)
      return color;
   else if (delta >= BEAD_HIGH)
      return color * rolloff(delta - BEAD_HIGH);
   else if (delta <= BEAD_LOW)
      return color * rolloff(BEAD_LOW - delta);
   else
      return vec3(0.0, 0.0, 0.0);
}

#define TEX(coord) texture(Source, coord).rgb

void main()
{
   vec3 mid_color = lookup(pixel_no, TEX(vTexCoord));
   FragColor = vec4(mid_color, 1.0);
}