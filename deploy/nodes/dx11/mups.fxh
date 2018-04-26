float pcount : PS_PARTICLECOUNT;
float pelsize : PS_ELEMENTSIZE;
float sysvalcount : PS_SYSVALCOUNT;
float bufsize : PS_BUFFERSIZE;
float2 Time : PS_TIME;
float EmitCounter : PS_EMITTERCOUNTER;
StructuredBuffer<uint> EmitCountOffs : PS_EMITTERCOUNTEROFFSET;

uint3 mups_position(uint i) {return uint3(i*pelsize+0,i*pelsize+1,i*pelsize+2);}
uint4 mups_velocity(uint i) {return uint4(i*pelsize+3,i*pelsize+4,i*pelsize+5,i*pelsize+6);}
uint3 mups_force(uint i) {return uint3(i*pelsize+7,i*pelsize+8,i*pelsize+9);}
uint4 mups_color(uint i) {return uint4(i*pelsize+10,i*pelsize+11,i*pelsize+12,i*pelsize+13);}
uint mups_size(uint i) {return i*pelsize+14;}
uint2 mups_age(uint i) {return uint2(i*pelsize+15,i*pelsize+16);}

float3 gmups_position(StructuredBuffer<float> mups, uint i) {return float3(mups[mups_position(i).x],mups[mups_position(i).y],mups[mups_position(i).z]);}
float4 gmups_velocity(StructuredBuffer<float> mups, uint i) {return float4(mups[mups_velocity(i).x],mups[mups_velocity(i).y],mups[mups_velocity(i).z],mups[mups_velocity(i).w]);}
float3 gmups_force(StructuredBuffer<float> mups, uint i) {return float3(mups[mups_force(i).x],mups[mups_force(i).y],mups[mups_force(i).z]);}
float4 gmups_color(StructuredBuffer<float> mups, uint i) {return float4(mups[mups_color(i).x],mups[mups_color(i).y],mups[mups_color(i).z],mups[mups_color(i).w]);}
float gmups_size(StructuredBuffer<float> mups, uint i) {return mups[mups_size(i).x];}
float2 gmups_age(StructuredBuffer<float> mups, uint i) {return float2(mups[mups_age(i).x],mups[mups_age(i).y]);}