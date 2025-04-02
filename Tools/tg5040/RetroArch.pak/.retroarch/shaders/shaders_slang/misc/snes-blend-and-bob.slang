#version 450

/*
   Bob-Deinterlacing
   Author: hunterk
   License: Public domain
   
   Note: This shader is designed to work with the typical interlaced output from an emulator, which displays both even and odd fields twice.
   As such, it is inappropriate for general video use unless the video has already been similarly woven beforehand.
*/

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec4 t1;

void main()
{
	gl_Position = global.MVP * Position;
	vTexCoord = TexCoord;
	vec2 ps = params.SourceSize.zw;
	float dx = ps.x;
	float dy = ps.y;
	t1 = vTexCoord.xxxy + vec4( -dx, 0., dx, 0.); // L, C, R
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec4 t1;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
	float y = 0.0;
	vec4 c;
	vec4 l;
	vec4 r;
	// assume anything with a vertical resolution greater than 400 lines is interlaced
	if (params.SourceSize.y > 400.0) y = params.SourceSize.y * vTexCoord.y + float(params.FrameCount);
	else	y = 2.000001 * params.SourceSize.y * vTexCoord.y;

	if (mod(y, 2.0) > 0.99999)
	{
		c = vec4(texture(Source, t1.yw + vec2(0.0, params.SourceSize.w)));
		l = vec4(texture(Source, t1.xw + vec2(0.0, params.SourceSize.w)));
		r = vec4(texture(Source, t1.zw + vec2(0.0, params.SourceSize.w)));
	}
	else
	{
		c = texture(Source, t1.yw);
		l = texture(Source, t1.xw);
		r = texture(Source, t1.zw);
	}
	
	vec4 final;
	if (params.SourceSize.x < 500.0) final = c;
	else
	{
		// pixel location
		float fp = round(fract(0.5*vTexCoord.x*params.SourceSize.x));

		// output
		final = (((l.x == c.x)||(r.x == c.x))&&((l.y == c.y)||(r.y == c.y))&&((l.z == c.z)||(r.z == c.z))) ? c : (fp > 0.5 ? mix(c,r,0.5) : mix(c,l,0.5));
	}
	FragColor = final;
}