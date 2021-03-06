//--------------------------------------------------------------------------------------
// Copyright (c) XU, Tianchen. All rights reserved.
//--------------------------------------------------------------------------------------

#define RAND_MAX	0x7fffffff;

//--------------------------------------------------------------------------------------
// Structs
//--------------------------------------------------------------------------------------
struct Particle
{
	float3 Pos;
	float3 Velocity;
	float LifeTime;
};

struct Emitter
{
	uint3 Indices;
	float2 Barycoord;
};

struct Vertex
{
	float3 Pos;
	float3 Nrm;
};

//--------------------------------------------------------------------------------------
// Constant buffer
//--------------------------------------------------------------------------------------
cbuffer cbPerObject
{
	matrix	g_world;
	matrix	g_worldPrev;
	float	g_timeStep;
	uint	g_baseSeed;
	uint	g_numEmitters;
};

static const float g_baseLife = 0.5f;

//--------------------------------------------------------------------------------------
// Buffers
//--------------------------------------------------------------------------------------
RWStructuredBuffer<Particle> g_rwParticles;
StructuredBuffer<Emitter>	g_roEmitters;
StructuredBuffer<Vertex>	g_roVertices;

uint rand(inout uint seed)
{
	// The same implementation of current Windows rand()
	// msvcrt.dll: 77C271D8 mov     ecx, [eax + 14h]
	// msvcrt.dll: 77C271DB imul    ecx, 343FDh
	// msvcrt.dll: 77C271E1 add     ecx, 269EC3h
	// msvcrt.dll: 77C271E7 mov     [eax + 14h], ecx
	// msvcrt.dll: 77C271EA mov     eax, ecx
	// msvcrt.dll: 77C271EC shr     eax, 10h
	// msvcrt.dll: 77C271EF and     eax, 7FFFh
	seed = seed * 0x343fd + 0x269ec3;   // a = 214013, b = 2531011

	return (seed >> 0x10) & RAND_MAX;
}

uint rand(inout uint seed, uint range)
{
	return rand(seed) % range;
}

[numthreads(64, 1, 1)]
void main(uint DTid : SV_DispatchThreadID)
{
	uint seed = g_baseSeed + DTid;

	// Load particle
	Particle particle = g_rwParticles[DTid];
	if (particle.LifeTime < g_baseLife + rand(seed, 3500) / 1000.0f) return;
	
	// Load emitter with a random index
	const uint emitterIdx = rand(seed, g_numEmitters);
	const Emitter emitter = g_roEmitters[emitterIdx];
	const float3 barycoord = { emitter.Barycoord, 1.0 - (emitter.Barycoord.x + emitter.Barycoord.y) };

	// Load triangle
	float3x3 v;
	[unroll] for (uint i = 0; i < 3; ++i)
		v[i] = g_roVertices[emitter.Indices[i]].Pos;

	// Get emitter position
	const float3 pos = mul(barycoord, v);

	// Particle emission
	particle.Pos = mul(float4(pos, 1.0), g_world).xyz;
	particle.Velocity = (particle.Pos - mul(float4(pos, 1.0), g_worldPrev).xyz) / g_timeStep;
	particle.LifeTime = 0.0;

	g_rwParticles[DTid] = particle;
}
