// DX11Utils.Native.h

#pragma once

#define SHADLIB(N) GFSDK_ShadowLib_##N
#define __GFSDK_DX11__ 1

#include <dxgi.h>
#include <d3d11.h>
#include <GFSDK_ShadowLib_Common.h>
#include <GFSDK_ShadowLib.h>

using namespace System;
using namespace System::ComponentModel::Composition;
using namespace System::Collections::Generic;
using namespace System::Runtime::InteropServices;

using namespace VVVV::Utils::VMath;
using namespace VVVV::PluginInterfaces::V2;
using namespace VVVV::PluginInterfaces::V1;

using namespace SlimDX;
using namespace SlimDX::Direct3D11;

using namespace FeralTic::DX11::Queries;
using namespace FeralTic::DX11::Resources;
using namespace FeralTic::DX11;

using namespace VVVV::DX11::Lib::Rendering;

namespace VVVV {
	namespace DX11 {
		namespace Nodes {
			public ref class NVUtils
			{
			public:
				static void V4MatToGFSDKMat(Matrix4x4 src, gfsdk_float4x4* dst)
				{
					dst->_11 = (gfsdk_F32)src.m11;
					dst->_12 = (gfsdk_F32)src.m12;
					dst->_13 = (gfsdk_F32)src.m13;
					dst->_14 = (gfsdk_F32)src.m14;

					dst->_21 = (gfsdk_F32)src.m21;
					dst->_22 = (gfsdk_F32)src.m22;
					dst->_23 = (gfsdk_F32)src.m23;
					dst->_24 = (gfsdk_F32)src.m24;

					dst->_31 = (gfsdk_F32)src.m31;
					dst->_32 = (gfsdk_F32)src.m32;
					dst->_33 = (gfsdk_F32)src.m33;
					dst->_34 = (gfsdk_F32)src.m34;

					dst->_41 = (gfsdk_F32)src.m41;
					dst->_42 = (gfsdk_F32)src.m42;
					dst->_43 = (gfsdk_F32)src.m43;
					dst->_44 = (gfsdk_F32)src.m44;
				}

				static void* m_Create_Proc = NULL;
				static void* m_GetDLLVersion_Proc = NULL;
				static void LoadShadowLibDLL()
				{
#if defined(_WIN64)
					LPCSTR dllpath = "GFSDK_ShadowLib_DX11.win64.dll";
#else
					LPCSTR dllpath = "GFSDK_ShadowLib_DX11.win32.dll";
#endif
					HMODULE module = LoadLibraryA(dllpath);

					m_GetDLLVersion_Proc = GetProcAddress(module, "GFSDK_ShadowLib_GetDLLVersion");
					m_Create_Proc = GetProcAddress(module, "GFSDK_ShadowLib_Create");
				}

#if defined(_WIN64)
				[DllImport("GFSDK_ShadowLib_DX11.win64.dll")]
#else
				[DllImport("GFSDK_ShadowLib_DX11.win32.dll")]
#endif
				static GFSDK_ShadowLib_Status GFSDK_ShadowLib_Create(
					const GFSDK_ShadowLib_Version* const			pVersion,
					GFSDK_ShadowLib_Context** const				ppContext,
					const GFSDK_ShadowLib_DeviceContext* const	pPlatformDevice,
					gfsdk_new_delete_t*												customAllocator);

#if defined(_WIN64)
				[DllImport("GFSDK_ShadowLib_DX11.win64.dll")]
#else
				[DllImport("GFSDK_ShadowLib_DX11.win32.dll")]
#endif
				static GFSDK_ShadowLib_Status GFSDK_ShadowLib_GetDLLVersion(GFSDK_ShadowLib_Version* const	pVersion);

			};
			public struct NVShadowNativePointers
			{
				// Contexts
				GFSDK_ShadowLib_Context* pContext;
				GFSDK_ShadowLib_DeviceContext* pDeviceContext;

				// Result Buffer
				GFSDK_ShadowLib_Buffer* pBuffer;
				GFSDK_ShadowLib_BufferDesc* pBufferDesc;
				GFSDK_ShadowLib_BufferRenderParams* pBufferParams;
				GFSDK_ShadowLib_ShaderResourceView* pBufferSRV;
				ID3D11Resource* pBufferD3DResource;

				// Shadowmap
				GFSDK_ShadowLib_Map* pMap;
				GFSDK_ShadowLib_MapDesc* pMapDesc;
				GFSDK_ShadowLib_MapRenderParams* pMapParams;
				GFSDK_ShadowLib_ShaderResourceView* pMapSRV;
				ID3D11Resource* pMapD3DResource;

				// Basic SM parameters
				gfsdk_float4x4* pMapView;
				gfsdk_float4x4* pMapProj;
				GFSDK_ShadowLib_Frustum* pMapFrustum;
			};
			public ref class NVShadowContext
			{
			public:
				/*
				typedef GFSDK_ShadowLib_Status(__cdecl * GetDLLVersion)(
					GFSDK_ShadowLib_Version* __GFSDK_RESTRICT__ const pVersion);

				typedef GFSDK_ShadowLib_Status(__cdecl * Create)(
					const GFSDK_ShadowLib_Version* __GFSDK_RESTRICT__ const			pVersion,
					GFSDK_ShadowLib_Context** __GFSDK_RESTRICT__ const				ppContext,
					const GFSDK_ShadowLib_DeviceContext* __GFSDK_RESTRICT__ const	pPlatformDevice,
					gfsdk_new_delete_t*												customAllocator);
				*/

				NVShadowContext();
				~NVShadowContext();

				bool Cascaded;
				bool Destroyed;

				NVShadowNativePointers* Np;

				// Managed Views
				Texture2D^ BufferTexture;
				DX11Texture2D^ BufferFtTex;
				ShaderResourceView^ BufferSRV;

				Texture2D^ MapTexture;
				DX11Texture2D^ MapFtTex;
				ShaderResourceView^ MapSRV;

				void CreateShadCtx(DX11RenderContext^ context, GFSDK_ShadowLib_BufferDesc* bufdesc, GFSDK_ShadowLib_MapDesc* mapdesc);
				void Update(DX11RenderContext^ context);
				void BeginRender(Matrix4x4 View, Matrix4x4 Projection, float Near, float Far);
				void EndRender();
				void SetDeviceContext(DX11RenderContext^ context);

				static GFSDK_ShadowLib_BufferDesc* GenerateBufferDesc(int bufwidth, int bufheight, int bufsampcount);
				static GFSDK_ShadowLib_MapDesc* GenerateMapDesc(int mapwidth, int mapheight, bool cascaded);
			};
			
			NVShadowContext::NVShadowContext()
			{
				Np = new NVShadowNativePointers();
				Np->pDeviceContext = new GFSDK_ShadowLib_DeviceContext();
			}
			NVShadowContext::~NVShadowContext()
			{
				Np->pContext->RemoveMap(&Np->pMap);
				Np->pContext->RemoveBuffer(&Np->pBuffer);
				Np->pContext->Destroy();
			}

			void NVShadowContext::SetDeviceContext(DX11RenderContext^ context)
			{
				Np->pDeviceContext->pD3DDevice = (ID3D11Device*)(void*)context->Device->ComPointer;
				Np->pDeviceContext->pDeviceContext = (ID3D11DeviceContext*)(void*)context->CurrentDeviceContext->ComPointer;
			}
			GFSDK_ShadowLib_BufferDesc* NVShadowContext::GenerateBufferDesc(int bufwidth, int bufheight, int bufsampcount)
			{
				GFSDK_ShadowLib_BufferDesc* ret = new GFSDK_ShadowLib_BufferDesc();
				ret->uResolutionWidth = bufwidth;
				ret->uResolutionHeight = bufheight;
				ret->uSampleCount = bufsampcount;
				ret->uViewportLeft = 0;
				ret->uViewportRight = bufwidth;
				ret->uViewportTop = 0;
				ret->uViewportBottom = bufheight;
				return ret;
			}
			GFSDK_ShadowLib_MapDesc* NVShadowContext::GenerateMapDesc(int mapwidth, int mapheight, bool cascaded)
			{
				GFSDK_ShadowLib_MapDesc* ret = new GFSDK_ShadowLib_MapDesc();
				ret->uResolutionWidth = mapwidth;
				ret->uResolutionHeight = mapheight;
				ret->eViewType = cascaded ? GFSDK_ShadowLib_ViewType::GFSDK_ShadowLib_ViewType_Cascades_4 : GFSDK_ShadowLib_ViewType::GFSDK_ShadowLib_ViewType_Single;
				ret->FrustumTraceMapDesc = *new GFSDK_ShadowLib_FrustumTraceMapDesc();
				ret->FrustumTraceMapDesc.bRequireFrustumTraceMap = true;
				ret->FrustumTraceMapDesc.uDynamicReprojectionCascades = 1;
				ret->FrustumTraceMapDesc.uResolutionWidth = mapwidth;
				ret->FrustumTraceMapDesc.uResolutionHeight = mapheight;
				ret->RayTraceMapDesc.uMaxNumberOfPrimitives = 1000000;
				ret->RayTraceMapDesc.uMaxNumberOfPrimitivesPerPixel = 10;
				ret->RayTraceMapDesc.uResolutionWidth = mapwidth;
				ret->RayTraceMapDesc.uResolutionHeight = mapheight;

				ret->RayTraceMapDesc = *new GFSDK_ShadowLib_RayTraceMapDesc();
				ret->RayTraceMapDesc.bRequirePrimitiveMap = false;
				return ret;
			}

			void NVShadowContext::CreateShadCtx(DX11RenderContext^ context, GFSDK_ShadowLib_BufferDesc* bufdesc, GFSDK_ShadowLib_MapDesc* mapdesc)
			{
				GFSDK_ShadowLib_Version version;
				//if (NVUtils::m_GetDLLVersion_Proc == NULL)
				//	NVUtils::LoadShadowLibDLL();
				//((GetDLLVersion)NVUtils::m_GetDLLVersion_Proc)(&version);
				GFSDK_ShadowLib_Status stat = NVUtils::GFSDK_ShadowLib_GetDLLVersion(&version);

				SetDeviceContext(context);

				//memset(pBufferSRV, 0, sizeof(pBufferSRV));

				Np->pContext = NULL;

				stat = NVUtils::GFSDK_ShadowLib_Create(&version, &Np->pContext, Np->pDeviceContext, NULL);
				//((Create)NVUtils::m_Create_Proc)(&version, ppContext, pDeviceContext, NULL);
				//GFSDK_ShadowLib_Create(&version, ppContext, pDeviceContext, NULL);

				Np->pBufferDesc = bufdesc;
				Np->pBuffer = NULL;
				stat = Np->pContext->AddBuffer(Np->pBufferDesc, &Np->pBuffer);

				Np->pMapDesc = mapdesc;
				Np->pMap = NULL;
				stat = Np->pContext->AddMap(Np->pMapDesc, Np->pBufferDesc, &Np->pMap);
			}
			void NVShadowContext::Update(DX11RenderContext^ context)
			{
				GFSDK_ShadowLib_Status stat = Np->pContext->RemoveBuffer(&Np->pBuffer);
				stat = Np->pContext->AddBuffer(Np->pBufferDesc, &Np->pBuffer);

				stat = Np->pContext->RemoveMap(&Np->pMap);
				stat = Np->pContext->AddMap(Np->pMapDesc, Np->pBufferDesc, &Np->pMap);

			}
			void NVShadowContext::BeginRender(Matrix4x4 View, Matrix4x4 Projection, float Near, float Far)
			{
				GFSDK_ShadowLib_Status stat = Np->pContext->SetMapRenderParams(Np->pMap, Np->pMapParams);

				if (Np->pMapProj == nullptr) Np->pMapProj = new gfsdk_float4x4();
				if (Np->pMapView == nullptr) Np->pMapView = new gfsdk_float4x4();
				if (Np->pMapFrustum == nullptr) Np->pMapFrustum = new GFSDK_ShadowLib_Frustum();
				NVUtils::V4MatToGFSDKMat(View, Np->pMapView);
				NVUtils::V4MatToGFSDKMat(Projection, Np->pMapProj);
				Np->pMapFrustum->fLeft = -1;
				Np->pMapFrustum->fRight = 1;
				Np->pMapFrustum->fTop = 1;
				Np->pMapFrustum->fBottom = -1;
				Np->pMapFrustum->fNear = Near;
				Np->pMapFrustum->fFar = Far;
				stat = Np->pContext->UpdateMapBounds(Np->pMap, Np->pMapView, Np->pMapProj, Np->pMapFrustum);

				//stat = Np->pContext->ClearBuffer(Np->pBuffer);
				stat = Np->pContext->InitializeMapRendering(Np->pMap, GFSDK_ShadowLib_MapRenderType::GFSDK_ShadowLib_MapRenderType_Depth);
				stat = Np->pContext->BeginMapRendering(Np->pMap, GFSDK_ShadowLib_MapRenderType::GFSDK_ShadowLib_MapRenderType_Depth, 0);
			}
			void NVShadowContext::EndRender()
			{
				GFSDK_ShadowLib_Status stat = Np->pContext->EndMapRendering(Np->pMap, GFSDK_ShadowLib_MapRenderType::GFSDK_ShadowLib_MapRenderType_Depth, 0);
				stat = Np->pContext->ClearBuffer(Np->pBuffer);
				stat = Np->pContext->RenderBuffer(Np->pMap, Np->pBuffer, Np->pBufferParams);
				
				if (Np->pBufferSRV == NULL) Np->pBufferSRV = new GFSDK_ShadowLib_ShaderResourceView();
				stat = Np->pContext->FinalizeBuffer(Np->pBuffer, Np->pBufferSRV);
			}

			public enum class NvhftsLightType
			{
				Directional,
				Spot
			};

			[PluginInfo(
				Name = "NVHybridFrustumTracedShadows",
				Category = "DX11.Texture2D",
				Author = "microdee"
			)]
			public ref class NVHybridFrustumTracedShadowsNode : IPluginEvaluate, IDisposable, IDX11RendererHost, IDX11Queryable
			{
			public:
				[Input("Depth In")]
				Pin<DX11Resource<DX11DepthStencil^>^>^ FInDepth;
				[Input("Single Sample Depth In")]
				Pin<DX11Resource<DX11Texture2D^>^>^ FResolvedDepth;
				[Input("Layer")]
				Pin<DX11Resource<DX11Layer^>^>^ FInLayer;
				[Input("Buffer Resolution", StepSize = 1, DefaultValues = gcnew array<double>(2) {512, 512})]
				Pin<Vector2D>^ FBufRes;
				[Input("Shadowmap Resolution", StepSize = 1, DefaultValues = gcnew array<double>(2) { 512, 512 })]
				Pin<Vector2D>^ FMapRes;
				[Input("Total Primitives", DefaultValue = 1)]
				Pin<int>^ FTotalPrims;

				[Input("World Space Box Min")]
				Pin<Vector3D>^ FWsBoxMin;
				[Input("World Space Box Max")]
				Pin<Vector3D>^ FWsBoxMax;

				[Input("Penumbra Max Threshold", DefaultValue = 100.0)]
				Pin<double>^ FPMaxThr;
				[Input("Penumbra Max Clamp", DefaultValue = 100.0)]
				Pin<double>^ FPMaxClamp;
				[Input("Minimum Penumbra Size Percent", DefaultValue = 1.0)]
				Pin<double>^ FPMinSizePercent;
				[Input("Minimum Penumbra Weight Threshold Percent", DefaultValue = 10.0)]
				Pin<double>^ FPMinWeightThrPercent;
				[Input("Penumbra Shift Minimum", DefaultValue = 2.0)]
				Pin<double>^ FPShiftMin;
				[Input("Penumbra Shift Maximum", DefaultValue = 1.0)]
				Pin<double>^ FPShiftMax;
				[Input("Penumbra Shift Maximum Lerp Threshold", DefaultValue = 0.01)]
				Pin<double>^ FPShiftMaxLerpThr;

				[Input("Light Type")]
				Pin<NvhftsLightType>^ FLightType;
				[Input("Light Size", DefaultValue = 1.0)]
				Pin<double>^ FLSize;
				[Input("Light Position")]
				Pin<Vector3D>^ FLPos;
				[Input("Light Lookat Point", DefaultValues = gcnew array<double>(3) { 0, 0, 1 })]
				Pin<Vector3D>^ FLLookat;
				[Input("Light View")]
				Pin<Matrix4x4>^ FLView;
				[Input("Light Projection")]
				Pin<Matrix4x4>^ FLProj;
				[Input("Eye View")]
				Pin<Matrix4x4>^ FEyeView;
				[Input("Eye Projection")]
				Pin<Matrix4x4>^ FEyeProj;
				[Input("Near", DefaultValue = 0.05)]
				Pin<double>^ FNear;
				[Input("Far", DefaultValue = 100.0)]
				Pin<double>^ FFar;

				[Input("Enabled")]
				Pin<bool>^ FEnabled;

				[Output("Buffer")]
				ISpread<DX11Resource<DX11Texture2D^>^>^ FOutBuf;
				[Output("Shadowmap")]
				ISpread<DX11Resource<DX11Texture2D^>^>^ FOutShadMap;
				[Output("Query", Order = 200, IsSingle = true)]
				ISpread<IDX11Queryable^>^ FOutQueryable;

				List<DX11RenderContext^>^ updateddevices = gcnew List<DX11RenderContext^>();
				List<DX11RenderContext^>^ rendereddevices = gcnew List<DX11RenderContext^>();

				gfsdk_float4x4* pEyeView = new gfsdk_float4x4();
				gfsdk_float4x4* pEyeProj = new gfsdk_float4x4();

				Dictionary<DX11RenderContext^, NVShadowContext^>^ Shadows = gcnew Dictionary<DX11RenderContext^, NVShadowContext^>();
				
				DX11RenderSettings^ settings = gcnew DX11RenderSettings();
				bool Reset;

				virtual event DX11QueryableDelegate^ BeginQuery;

				virtual event DX11QueryableDelegate^ EndQuery;

				NVHybridFrustumTracedShadowsNode() { }
				~NVHybridFrustumTracedShadowsNode();

				property bool IsEnabled
				{
					virtual bool get() { return FEnabled[0]; }
				}

				virtual void Render(DX11RenderContext^ context);
				virtual void Update(DX11RenderContext^ context);
				virtual void Destroy(DX11RenderContext^ OnDevice, bool force);

				virtual void Evaluate(int SpreadMax);
			};

			NVHybridFrustumTracedShadowsNode::~NVHybridFrustumTracedShadowsNode()
			{
				for each (NVShadowContext^ shad in Shadows->Values)
				{
					delete shad;
				}
			}

			void NVHybridFrustumTracedShadowsNode::Evaluate(int SpreadMax)
			{
				if (!FInLayer->PluginIO->IsConnected) return;
				rendereddevices->Clear();
				updateddevices->Clear();
				Reset = FBufRes->IsChanged || FMapRes->IsChanged /*|| FCascaded->IsChanged */;
				if(FOutBuf[0] == nullptr)
				{
					FOutBuf[0] = gcnew DX11Resource<DX11Texture2D^>();
					Reset = true;
				}
				if (FOutShadMap[0] == nullptr)
				{
					FOutShadMap[0] = gcnew DX11Resource<DX11Texture2D^>();
					Reset = true;
				}
				if (FOutQueryable[0] == nullptr) { FOutQueryable[0] = this; }
			}
			void NVHybridFrustumTracedShadowsNode::Update(DX11RenderContext^ context)
			{
				if (updateddevices->Contains(context)) return;
				if (!FInDepth->PluginIO->IsConnected) return;
				if (FInDepth->SliceCount == 0) return;
				if (FInDepth[0] == nullptr) return;
				NVShadowContext^ currshadow;
				if (!Shadows->ContainsKey(context)) // not created yet
				{
					currshadow = gcnew NVShadowContext();
					GFSDK_ShadowLib_BufferDesc* bufdesc = NVShadowContext::GenerateBufferDesc((int)FBufRes[0].x, (int)FBufRes[0].y, 1);
					GFSDK_ShadowLib_MapDesc* mapdesc = NVShadowContext::GenerateMapDesc((int)FMapRes[0].x, (int)FMapRes[0].y, false);
					currshadow->CreateShadCtx(context, bufdesc, mapdesc);
					Shadows->Add(context, currshadow);
				}
				else // already created
				{
					currshadow = Shadows[context];

					bool notneeded = currshadow->Np->pBufferDesc->uResolutionWidth == (int)FBufRes[0].x;
					notneeded = notneeded || currshadow->Np->pBufferDesc->uResolutionWidth == (int)FBufRes[0].x;
					notneeded = notneeded || currshadow->Np->pMapDesc->uResolutionWidth == (int)FMapRes[0].x;
					notneeded = notneeded || currshadow->Np->pMapDesc->uResolutionHeight == (int)FMapRes[0].y;
					if (notneeded)
					{
						updateddevices->Add(context);
						return;
					}

					currshadow->Np->pBufferDesc->uResolutionWidth = (int)FBufRes[0].x;
					currshadow->Np->pBufferDesc->uResolutionHeight = (int)FBufRes[0].y;
					currshadow->Np->pMapDesc->uResolutionWidth = (int)FMapRes[0].x;
					currshadow->Np->pMapDesc->uResolutionHeight = (int)FMapRes[0].y;
					currshadow->Np->pMapDesc->eViewType = GFSDK_ShadowLib_ViewType::GFSDK_ShadowLib_ViewType_Single;
					currshadow->Update(context);
				}
				// Initialize SM parameters
				if (currshadow->Np->pBufferParams == NULL) currshadow->Np->pBufferParams = new GFSDK_ShadowLib_BufferRenderParams();
				if (currshadow->Np->pMapParams == NULL) currshadow->Np->pMapParams = new GFSDK_ShadowLib_MapRenderParams();

				// Simple fields
				currshadow->Np->pMapParams->eTechniqueType = GFSDK_ShadowLib_TechniqueType::GFSDK_ShadowLib_TechniqueType_PCSS;
				currshadow->Np->pMapParams->eCullModeType = GFSDK_ShadowLib_CullModeType::GFSDK_ShadowLib_CullModeType_None;

				// Assign Depth Buffer
				GFSDK_ShadowLib_DepthBufferDesc depthbufdesc = currshadow->Np->pMapParams->DepthBufferDesc;
				DX11Resource<DX11DepthStencil^>^ dsres = FInDepth[0];
				DX11DepthStencil^ ds = dsres[context];

				depthbufdesc.DepthSRV.pSRV = (ID3D11ShaderResourceView*)(void*)ds->SRV->ComPointer;
				depthbufdesc.ReadOnlyDSV.pDSV = (ID3D11DepthStencilView*)(void*)ds->ReadOnlyDSV->ComPointer;

				if(FResolvedDepth->PluginIO->IsConnected) // Is separate single sample resolved depth provided?
				{
					DX11Resource<DX11Texture2D^>^ resdsres = FResolvedDepth[0];
					DX11Texture2D^ resds = resdsres[context];
					depthbufdesc.ResolvedDepthSRV.pSRV = (ID3D11ShaderResourceView*)(void*)resds->SRV->ComPointer;
				}
				else
				{
					//depthbufdesc.ResolvedDepthSRV.pSRV = (ID3D11ShaderResourceView*)(void*)ds->SRV->ComPointer;
					depthbufdesc.ResolvedDepthSRV.pSRV = NULL;
				}
				currshadow->Np->pMapParams->DepthBufferDesc = depthbufdesc;


				updateddevices->Add(context);
			}
			void NVHybridFrustumTracedShadowsNode::Render(DX11RenderContext^ context)
			{
				if (!updateddevices->Contains(context)) Update(context);
				if (!FInDepth->PluginIO->IsConnected) return;
				if (FInDepth->SliceCount == 0) return;
				if (FInDepth[0] == nullptr) return;
				if (!FInLayer->PluginIO->IsConnected) return;
				if (rendereddevices->Contains(context)) return;
				if (!FEnabled[0]) return;
				BeginQuery(context);

				NVShadowContext^ currshadow = Shadows[context];

				// Map Render Parameters
				// Eye/Camera matrices
				NVUtils::V4MatToGFSDKMat(FEyeView[0], pEyeView);
				currshadow->Np->pMapParams->m4x4EyeViewMatrix = *pEyeView;

				NVUtils::V4MatToGFSDKMat(FEyeProj[0], pEyeProj);
				currshadow->Np->pMapParams->m4x4EyeProjectionMatrix = *pEyeProj;

				// World space box
				gfsdk_float3 wsbbmin = currshadow->Np->pMapParams->v3WorldSpaceBBox[0];
				gfsdk_float3 wsbbmax = currshadow->Np->pMapParams->v3WorldSpaceBBox[1];

				wsbbmin.x = (float)FWsBoxMin[0].x;
				wsbbmin.y = (float)FWsBoxMin[0].y;
				wsbbmin.z = (float)FWsBoxMin[0].z;

				wsbbmax.x = (float)FWsBoxMax[0].x;
				wsbbmax.y = (float)FWsBoxMax[0].y;
				wsbbmax.z = (float)FWsBoxMax[0].z;

				currshadow->Np->pMapParams->v3WorldSpaceBBox[0] = wsbbmin;
				currshadow->Np->pMapParams->v3WorldSpaceBBox[1] = wsbbmax;

				// PCSS options
				GFSDK_ShadowLib_PCSSPenumbraParams pcssp = currshadow->Np->pMapParams->PCSSPenumbraParams;
				pcssp.fMaxThreshold = (float)FPMaxThr[0];
				pcssp.fMaxClamp = (float)FPMaxClamp[0];
				for (int i = 0; i < 4; i++)
					pcssp.fMinSizePercent[i] = (float)FPMinSizePercent[0];
				pcssp.fMinWeightThresholdPercent = (float)FPMinWeightThrPercent[0];
				pcssp.fShiftMax = (float)FPShiftMax[0];
				pcssp.fShiftMin = (float)FPShiftMin[0];
				pcssp.fShiftMaxLerpThreshold = (float)FPShiftMaxLerpThr[0];
				currshadow->Np->pMapParams->PCSSPenumbraParams = pcssp;

				// Light
				GFSDK_ShadowLib_LightDesc lightd = currshadow->Np->pMapParams->LightDesc;
				lightd.eLightType = (GFSDK_ShadowLib_LightType)((unsigned int)FLightType[0]);
				lightd.fLightSize = (float)FLSize[0];

				lightd.v3LightPos[0].x = (float)FLPos[0].x;
				lightd.v3LightPos[0].y = (float)FLPos[0].y;
				lightd.v3LightPos[0].z = (float)FLPos[0].z;

				lightd.v3LightLookAt[0].x = (float)FLLookat[0].x;
				lightd.v3LightLookAt[0].y = (float)FLLookat[0].y;
				lightd.v3LightLookAt[0].z = (float)FLLookat[0].z;

				currshadow->Np->pMapParams->LightDesc = lightd;

				// Begin render
				currshadow->BeginRender(FLView[0], FLProj[0], (float)FNear[0], (float)FFar[0]);

				settings->View = Matrix4x4Extensions::ToSlimDXMatrix(FLView[0]);
				settings->Projection = Matrix4x4Extensions::ToSlimDXMatrix(FLProj[0]);
				settings->ViewProjection = settings->View * settings->Projection;
				settings->RenderWidth = FMapRes[0].x;
				settings->RenderHeight = FMapRes[0].y;
				settings->RenderDepth = 1;
				settings->BackBuffer = nullptr;

				DX11Resource<DX11Layer^>^ layerres = FInLayer[0];
				DX11Layer^ layer = layerres[context];

				layer->Render(context, settings);
				currshadow->Np->pContext->IncrementMapPrimitiveCounter(currshadow->Np->pMap, GFSDK_ShadowLib_MapRenderType::GFSDK_ShadowLib_MapRenderType_Depth, (gfsdk_U32)FTotalPrims[0]);

				currshadow->EndRender();

				// convert buffer to managed
				if (currshadow->BufferTexture == nullptr)
				{
					currshadow->BufferSRV = ShaderResourceView::FromPointer((IntPtr)currshadow->Np->pBufferSRV->pSRV);
					currshadow->Np->pBufferSRV->pSRV->GetResource(&currshadow->Np->pBufferD3DResource);
					ID3D11Texture2D* pBuftex = (ID3D11Texture2D*)currshadow->Np->pBufferD3DResource;
					currshadow->BufferTexture = Texture2D::FromPointer(IntPtr::IntPtr(pBuftex));
					currshadow->BufferFtTex = DX11Texture2D::FromTextureAndSRV(context, currshadow->BufferTexture, currshadow->BufferSRV);
				}
				DX11Resource<DX11Texture2D^>^ outbufres = FOutBuf[0];
				outbufres[context] = currshadow->BufferFtTex;

				// convert map to managed
				if (currshadow->Np->pMapSRV == NULL)
				{
					gfsdk_float4x4 lvm, lpm;
					GFSDK_ShadowLib_Frustum lft;
					currshadow->Np->pMapSRV = new GFSDK_ShadowLib_ShaderResourceView();
					currshadow->Np->pContext->GetMapData(currshadow->Np->pMap, currshadow->Np->pMapSRV, &lvm, &lpm, &lft);

					currshadow->MapSRV = ShaderResourceView::FromPointer((IntPtr)currshadow->Np->pMapSRV->pSRV);
					currshadow->Np->pMapSRV->pSRV->GetResource(&currshadow->Np->pMapD3DResource);
					ID3D11Texture2D* pMaptex = (ID3D11Texture2D*)currshadow->Np->pMapD3DResource;
					currshadow->MapTexture = Texture2D::FromPointer(IntPtr::IntPtr(pMaptex));
					currshadow->MapFtTex = DX11Texture2D::FromTextureAndSRV(context, currshadow->MapTexture, currshadow->MapSRV);
				}
				DX11Resource<DX11Texture2D^>^ outmapres = FOutShadMap[0];
				outmapres[context] = currshadow->MapFtTex;

				EndQuery(context);
			}

			void NVHybridFrustumTracedShadowsNode::Destroy(DX11RenderContext^ context, bool force)
			{
				/*
				NVShadowContext^ currshadow = Shadows[context];
				delete currshadow;
				Shadows->Remove(context);
				FOutBuf[0]->Dispose(context);
				*/
			}
		}
	}
}