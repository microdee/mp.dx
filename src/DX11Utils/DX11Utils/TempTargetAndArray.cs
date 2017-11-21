using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using VVVV.PluginInterfaces.V2;
using VVVV.Utils.VMath;
using System.ComponentModel.Composition;
using VVVV.PluginInterfaces.V1;
using SlimDX.DXGI;
using VVVV.DX11.Lib.Rendering;

using FeralTic.DX11;
using FeralTic.DX11.Resources;
using mp.dx.dx11.Resources;
using SlimDX.Direct3D11;
using VVVV.DX11;
using VVVV.Utils.VColor;


namespace mp.dx.dx11.Nodes
{
    [PluginInfo(Name = "TemptargetAndArray", Category = "DX11", Author = "vux,tonfilm,microdee", AutoEvaluate = false)]
    public class DX11TempRTRendererNode : AbstractDX11Renderer2DNodeAdvanced
    {
        #region Inputs
        [Input("Generate Mip Maps", Order = 4)]
        protected IDiffSpread<bool> FInDoMipMaps;

        [Input("Mip Map Levels", Order = 5)]
        protected IDiffSpread<int> FInMipLevel;

        [Input("Shared Texture", Order = 6)]
        protected IDiffSpread<bool> FInSharedTex;

        [Input("Texture Array Size", DefaultValues = new double[] { 256, 256 }, StepSize = 1.0)]
        protected ISpread<Vector2D> FTASize;
        [Input("Texture Array Depth", DefaultValue = 1)]
        protected ISpread<int> FTADepth;
        [Input("Texture Array Format", DefaultEnumEntry = "R32_Float")]
        protected ISpread<Format> FTAFormat;
        [Input("Clear Texture Array")]
        protected ISpread<bool> FTAClear;
        [Input("Texture Array Clear Color", DefaultColor = new [] {0.0, 0.0, 0.0, 1.0})]
        protected ISpread<RGBAColor> FTAClearCol;
        #endregion

        #region Output Pins
        [Output("Buffer Size")]
        protected ISpread<Vector2D> FOutBufferSize;

        [Output("Buffers", IsSingle = true)]
        protected ISpread<DX11Resource<DX11Texture2D>> FOutBuffers;
        [Output("Texture Array", IsSingle = true)]
        protected ISpread<DX11Resource<DX11RWTextureArray2D>> FOutTexArray;

        [Output("AA Texture Out", IsSingle = true, Visibility = PinVisibility.OnlyInspector)]
        protected ISpread<DX11Resource<DX11Texture2D>> FOutAABuffers;

        #endregion

        private bool genmipmap;
        private int mipmaplevel;

        private bool invalidate = true;

        private Dictionary<DX11RenderContext, DX11RenderTarget2D> targets = new Dictionary<DX11RenderContext, DX11RenderTarget2D>();
        private Dictionary<DX11RenderContext, DX11RenderTarget2D> targetresolve = new Dictionary<DX11RenderContext, DX11RenderTarget2D>();
        private RenderTargetManager rtm;
        private SlimDX.DXGI.Format format;

        #region Constructor
        [ImportingConstructor()]
        public DX11TempRTRendererNode(IPluginHost FHost, IIOFactory iofactory)
        {
            this.depthmanager = new DepthBufferManager(FHost, iofactory);
            this.rtm = new RenderTargetManager(FHost, iofactory);
        }
        #endregion

        #region On Evaluate
        protected override void OnEvaluate(int SpreadMax)
        {
            if (this.FOutBuffers[0] == null) { this.FOutBuffers[0] = new DX11Resource<DX11Texture2D>(); }
            if (this.FOutTexArray[0] == null) { this.FOutTexArray[0] = new DX11Resource<DX11RWTextureArray2D>(); }
            if (this.FOutAABuffers[0] == null) { this.FOutAABuffers[0] = new DX11Resource<DX11Texture2D>(); }

            if (this.FInAASamplesPerPixel.IsChanged
                || this.FInDoMipMaps.IsChanged
                || this.FInMipLevel.IsChanged
                || this.FInSharedTex.IsChanged
                || this.FTADepth.IsChanged
                || this.FTAFormat.IsChanged)
            {
                this.sd.Count = Convert.ToInt32(this.FInAASamplesPerPixel[0].Name);
                this.sd.Quality = 0;
                this.genmipmap = this.FInDoMipMaps[0];
                this.mipmaplevel = Math.Max(FInMipLevel[0], 0);
                this.depthmanager.NeedReset = true;
                this.invalidate = true;
            }

            this.FOutBufferSize[0] = new Vector2D(this.width, this.height);
        }
        #endregion

        #region On Update
        protected override void OnUpdate(DX11RenderContext context)
        {
            bool resetta = true;
            try
            {
                var ptadesc = FOutTexArray[0][context].Description;
                resetta = FTADepth[0] != ptadesc.ArraySize ||
                          (int) FTASize[0].x != ptadesc.Width ||
                          (int) FTASize[0].y != ptadesc.Height ||
                          FTAFormat[0] != ptadesc.Format;
            }
            catch (Exception e) { }
            if (resetta)
            {
                try
                {
                    FOutTexArray[0].Dispose(context);
                }
                catch (Exception e) { }
                var tadesc = new Texture2DDescription
                {
                    ArraySize = FTADepth[0],
                    Width = (int)FTASize[0].x,
                    Height = (int)FTASize[0].y,
                    Format = FTAFormat[0],
                    BindFlags = BindFlags.UnorderedAccess | BindFlags.ShaderResource,
                    //CpuAccessFlags = CpuAccessFlags.None,
                    MipLevels = 1,
                    OptionFlags = ResourceOptionFlags.None,
                    SampleDescription = new SampleDescription(1, 0),
                    //Usage = ResourceUsage.Default
                };
                FOutTexArray[0][context] = new DX11RWTextureArray2D(context, new Texture2D(context.Device, tadesc));

                foreach (var semantic in CustomSemantics)
                {
                    semantic.Dispose();
                }
                CustomSemantics.Clear();
                CustomSemantics.Add(new RWTexture2dArrayRenderSemantic("TEXTUREARRAY", false)
                {
                    Data = FOutTexArray[0][context]
                });
                CustomSemantics.Add(new Texture2dArrayRenderSemantic("TEXTUREARRAY_SRV", false)
                {
                    Data = FOutTexArray[0][context]
                });
            }

            TexInfo ti = this.rtm.GetRenderTarget(context);

            if (ti.w != this.width || ti.h != this.height || !this.targets.ContainsKey(context) || this.invalidate
                || ti.format != this.format)
            {
                this.invalidate = false;
                this.width = ti.w;
                this.height = ti.h;
                this.format = ti.format;

                this.depthmanager.NeedReset = true;

                if (targets.ContainsKey(context))
                {
                    context.ResourcePool.Unlock(targets[context]);
                }

                if (targetresolve.ContainsKey(context))
                {
                    context.ResourcePool.Unlock(targetresolve[context]);
                }

                int aacount = Convert.ToInt32(this.FInAASamplesPerPixel[0].Name);
                int aaquality = 0;

                if (aacount > 1)
                {
                    List<SampleDescription> sds = context.GetMultisampleFormatInfo(ti.format);
                    int maxlevels = sds[sds.Count - 1].Count;

                    if (aacount > maxlevels)
                    {
                        FHost.Log(TLogType.Warning, "Multisample count too high for this format, reverted to: " + maxlevels);
                        aacount = maxlevels;
                    }

                    DX11RenderTarget2D temptarget = context.ResourcePool.LockRenderTarget(this.width, this.height, ti.format, new SampleDescription(aacount, aaquality), this.FInDoMipMaps[0], this.FInMipLevel[0], this.FInSharedTex[0]).Element;
                    DX11RenderTarget2D temptargetresolve = context.ResourcePool.LockRenderTarget(this.width, this.height, ti.format, new SampleDescription(1, 0), this.FInDoMipMaps[0], this.FInMipLevel[0], this.FInSharedTex[0]).Element;

                    targets[context] = temptarget;
                    targetresolve[context] = temptargetresolve;

                    this.FOutBuffers[0][context] = temptargetresolve;
                    this.FOutAABuffers[0][context] = temptarget;
                }
                else
                {
                    //Bind both texture as same output
                    DX11RenderTarget2D temptarget = context.ResourcePool.LockRenderTarget(this.width, this.height, ti.format, new SampleDescription(aacount, aaquality), this.FInDoMipMaps[0], this.FInMipLevel[0], this.FInSharedTex[0]).Element;
                    targets[context] = temptarget;

                    this.FOutBuffers[0][context] = temptarget;
                    this.FOutAABuffers[0][context] = temptarget;
                }
            }
        }
        #endregion

        protected override IDX11RWResource GetMainTarget(DX11RenderContext context)
        {
            return this.FOutTexArray[0][context];
        }

        #region On Destroy
        protected override void OnDestroy(DX11RenderContext context, bool force)
        {
            //Release lock on target
            if (targets.ContainsKey(context))
            {
                context.ResourcePool.Unlock(targets[context]);
                targets.Remove(context);
            }

            if (targetresolve.ContainsKey(context))
            {
                context.ResourcePool.Unlock(targetresolve[context]);
                targetresolve.Remove(context);
            }
            try
            {
                FOutTexArray[0].Dispose(context);
            }
            catch (Exception e) { }



        }
        #endregion

        #region Before Render
        protected override void BeforeRender(DX11GraphicsRenderer renderer, DX11RenderContext context)
        {
            renderer.EnableDepth = this.FInDepthBuffer[0];
            renderer.DepthStencil = this.depthmanager.GetDepthStencil(context);
            renderer.DepthMode = this.depthmanager.Mode;
            renderer.SetRenderTargets(targets[context]);
            if(FTAClear[0])
                context.CurrentDeviceContext.ClearUnorderedAccessView(FOutTexArray[0][context].UAV, new [] { (float)FTAClearCol[0].R, (float)FTAClearCol[0].G, (float)FTAClearCol[0].B, (float)FTAClearCol[0].A});
        }
        #endregion

        #region After Render
        protected override void AfterRender(DX11GraphicsRenderer renderer, DX11RenderContext context)
        {
            if (this.sd.Count > 1)
            {
                context.CurrentDeviceContext.ResolveSubresource(targets[context].Resource, 0, targetresolve[context].Resource,
                    0, targets[context].Format);
            }

            if (this.genmipmap && this.sd.Count == 1)
            {
                for (int i = 0; i < this.FOutBuffers.SliceCount; i++)
                {
                    context.CurrentDeviceContext.GenerateMips(targets[context].SRV);
                }
            }
        }
        #endregion

        #region Dispose
        protected override void OnDispose()
        {
            FOutTexArray[0].Dispose();
        }
        #endregion
    }
}