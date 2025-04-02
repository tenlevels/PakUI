#version 450

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;

    float frameShape;
	float frameLimit;
	float frameSharpness;
    float TVNoise;
    float PALSignal;
    float phosphors;
    float border;
} params;

#pragma parameter frameShape "Border mask shape" 0.35 0.0 1.0 0.01
#pragma parameter frameLimit "Border mask limit" 0.30 0.0 1.0 0.01
#pragma parameter frameSharpness "Border mask sharpness" 1.10 0.0 4.0 0.01
#pragma parameter TVNoise "PAL signal modulation + noise" 1.0 0.0 1.0 1.0
#pragma parameter PALSignal "PAL signal simulation" 1.0 0.0 1.0 1.0
#pragma parameter phosphors "Phosphor mask" 1.0 0.0 1.0 1.0
#pragma parameter border "Border mask" 1.0 0.0 1.0 1.0

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

float rand(float p){vec2 s=vec2(p,p);float e=12.9898,r=78.233,t=43758.5,v=dot(s.rg,vec2(e,r)),S=mod(v,3.14);return fract(sin(S)*t);}vec2 crt(vec2 s,float e){return s=(s-.5)*2.,s*=.5,s.r*=1.+pow(abs(s.g)/e,2.),s.g*=1.+pow(abs(s.r)/e,2.),s=s+.5,s;}void main(){vec4 s=vec4(0.);vec2 e=vTexCoord.rg,v=crt(e,2.),r=v;mat3 p=mat3(.299,-.147,.615,.587,-.289,-.515,.114,.436,-.1),b=mat3(1.,1.,1.,0.,-.395,2.032,1.14,-.581,0.);float t=1.;if(params.TVNoise==1.)t-=rand(v.r*params.FrameCount*.1+v.g*params.FrameCount*50.+params.FrameCount)*.5;if(params.PALSignal==1.){vec3 f=vec3(0.);float c=.3,g=-.002;for(int S=10;S>=0;S-=1){float m=float(S)/10.;if(m<0.)m=0.;float a=m*-.05*c+g,i=m*.1*c+g;vec3 l=(vec3(1.)-pow(vec3(m),vec3(.2,1.,1.)))*.2;vec2 o=r+vec2(a,0.),u=r+vec2(i,0.);f+=p*texture(Source,o).rgb*l;f+=p*texture(Source,u).rgb*l;}f.r=f.r*.2+(p*texture(Source,r).rgb).r*.8;s.rgb=b*f*t;}else s.rgb=texture(Source,r).rgb;if(params.phosphors==1.){float S=e.g*params.OutputSize.g*params.OutputSize.g/params.OutputSize.g;vec3 m=mix(vec3(1.,.7,1.),vec3(.7,1.,.7),floor(mod(S,2.)));s.rgb*=m;}if(params.border==1.){vec2 c=-1.+2.*crt(e,2.);float S=(1.-c.r*c.r)*(1.-c.g*c.g),m=clamp(params.frameSharpness*(pow(S,params.frameShape)-params.frameLimit),0.,1.);s.rgb*=m;}FragColor=vec4(s.rgb,1.);}

