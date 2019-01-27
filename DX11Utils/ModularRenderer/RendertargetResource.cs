using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Fasterflect;
using FeralTic.DX11;
using FeralTic.DX11.Resources;
using mp.pddn;
using md.stdl.Coding;
using SlimDX.Direct3D11;
using SlimDX.DXGI;
using VVVV.DX11;
using VVVV.DX11.Internals.Helpers;
using VVVV.PluginInterfaces.V2.Graph;
using VVVV.DX11.Lib.Rendering;
using VVVV.PluginInterfaces.V1;
using SlimDevice = SlimDX.Direct3D11.Device;

namespace DX11Utils.ModularRenderer
{
    public enum AaSampleCount
    {
        _1 = 1,
        _2 = 2,
        _4 = 4,
        _8 = 8,
        _16 = 16,
        _32 = 32
    };

    public abstract class PerVisitorRenderTargetComponent
    {
        public IModularRenderTarget Parent { get; set; }

        public PerVisitorRenderTargetComponent(IModularRenderTarget parent)
        {
            Parent = parent;
        }

        public PerVisitorRenderTargetComponent()
        {
            throw new NotImplementedException();
        }

        [VvvvIgnore]
        public DX11Resource<IDX11DepthStencil> DepthInput { get; set; } = new DX11Resource<IDX11DepthStencil>();

        public DX11Resource<IDX11DepthStencil> DepthOutput { get; set; }

        [VvvvIgnore]
        public HashSet<DX11RenderContext> UpdatedDevices { get; } = new HashSet<DX11RenderContext>();

        [VvvvIgnore]
        public HashSet<DX11RenderContext> RenderedDevices { get; } = new HashSet<DX11RenderContext>();

        public void Destroy(DX11RenderContext context)
        {
            DepthInput.Dispose(context);
            DepthOutput.Dispose(context);
        }

        public void Dispose()
        {
            DepthInput.Dispose();
            DepthOutput.Dispose();
        }

        public DepthStencilView GetDsv(DX11RenderContext context)
        {
            switch (Parent.DepthBufferUsageMode)
            {
                case eDepthBufferMode.ReadOnly: return DepthInput?[context].ReadOnlyDSV;
                case eDepthBufferMode.Standard: return DepthOutput[context].ReadOnlyDSV;
                default: return null;
            }
        }

        public IDX11DepthStencil GetDepthStencil(DX11RenderContext context)
        {
            switch (Parent.DepthBufferUsageMode)
            {
                case eDepthBufferMode.Standard: return DepthOutput[context];
                case eDepthBufferMode.ReadOnly: return DepthInput?[context];
                default: return null;
            }
        }

        public void ClearDepth(DX11RenderContext context)
        {
            if (Parent.DepthBufferUsageMode == eDepthBufferMode.Standard)
            {
                context.CurrentDeviceContext.ClearDepthStencilView(
                    DepthOutput[context].DSV,
                    DepthStencilClearFlags.Depth | DepthStencilClearFlags.Stencil,
                    Parent.ClearDepthValue, 0);
            }
        }

        protected abstract IDX11DepthStencil CreateDepthStencil(DX11RenderContext context);

        public void UpdateDepth(DX11RenderContext context)
        {
            if (Parent.DepthBufferUsageMode == eDepthBufferMode.Standard)
            {
                if (Parent.Reset || !DepthOutput.Contains(context))
                {
                    DepthOutput.Dispose(context);
                    DepthOutput[context] = CreateDepthStencil(context);
                }
            }
        }
    }

    public interface IModularRenderTarget : ITextureResourceBase
    {
        AaSampleCount AaSamplesPerPixel { get; set; }
        eDepthBufferMode DepthBufferUsageMode { get; set; }
        List<string> AllowedDepthFormats { get; }
        SlimDX.DXGI.Format DepthFormat { get; set; }
        bool DepthFormatChanged { get; }
        bool ClearDepth { get; set; }
        float ClearDepthValue { get; set; }
        SampleDescription SampleDescription { get; set; }
        ConcurrentDictionary<ModularRenderer, PerVisitorRenderTargetComponent> PerVisitorComponents { get; }
        Action<DX11RenderContext, PerVisitorRenderTargetComponent> OnRender { get; set; }

        IDX11RWResource GetMainTarget(DX11RenderContext device, ModularRenderer visitor);
        SampleDescription TrySampleDescription(DX11RenderContext context, SampleDescription sd);
    }

    public abstract class ModularRenderTarget<TRes> : TextureResourceBase<TRes>, IModularRenderTarget
        where TRes : IDX11Resource
    {
        private SlimDX.DXGI.Format _depthFormat;

        public AaSampleCount AaSamplesPerPixel { get; set; }

        public eDepthBufferMode DepthBufferUsageMode { get; set; }

        public SampleDescription SampleDescription { get; set; } = new SampleDescription(1, 0);

        public List<string> AllowedDepthFormats { get; } =
            DX11EnumFormatHelper.NullDeviceFormats.GetAllowedFormats(SlimDX.Direct3D11.FormatSupport.DepthStencil);

        public SlimDX.DXGI.Format DepthFormat
        {
            get => _depthFormat;
            set
            {
                DepthFormatChanged = true;
                _depthFormat = value;
            }
        }

        public bool DepthFormatChanged { get; private set; }

        public bool ClearDepth { get; set; }

        public float ClearDepthValue { get; set; }

        public ConcurrentDictionary<ModularRenderer, PerVisitorRenderTargetComponent> PerVisitorComponents { get; } =
            new ConcurrentDictionary<ModularRenderer, PerVisitorRenderTargetComponent>();

        protected abstract PerVisitorRenderTargetComponent CreatePerVisitorComponent();

        public override void OnEvaluate(ModularRenderer visitor)
        {
            base.OnEvaluate(visitor);
            var pvc = PerVisitorComponents.GetOrAdd(visitor, v => CreatePerVisitorComponent());
            pvc.RenderedDevices.Clear();
            pvc.UpdatedDevices.Clear();
        }

        public virtual IDX11RWResource GetMainTarget(DX11RenderContext device, ModularRenderer visitor)
        {
            return null;
        }

        public override void Update(DX11RenderContext context, ModularRenderer visitor)
        {
            base.Update(context, visitor);

            var pvc = PerVisitorComponents.GetOrAdd(visitor, v => CreatePerVisitorComponent());

            SlimDevice device = context.Device;
            if(pvc.UpdatedDevices.Contains(context)) return;

            OnUpdate(context, pvc);

            pvc.UpdateDepth(context);
            pvc.UpdatedDevices.Add(context);
        }

        protected virtual void OnUpdate(DX11RenderContext context, PerVisitorRenderTargetComponent pvc) { }

        public override void Render(DX11RenderContext context, ModularRenderer visitor)
        {
            base.Render(context, visitor);
            
            var pvc = PerVisitorComponents.GetOrAdd(visitor, v => CreatePerVisitorComponent());
            if(!pvc.UpdatedDevices.Contains(context)) Update(context, visitor);
            if (pvc.RenderedDevices.Contains(context)) return;

            if (IsEnabled)
            {
                OnBeforeRender(context, pvc);
                
                if (ClearDepth) pvc.ClearDepth(context);
                DoClear(context, pvc);

                OnRender?.Invoke(context, pvc);

                OnAfterRender(context, pvc);

                pvc.RenderedDevices.Add(context);
            }
        }

        public Action<DX11RenderContext, PerVisitorRenderTargetComponent> OnRender { get; set; }

        protected abstract void DoClear(DX11RenderContext context, PerVisitorRenderTargetComponent pvc);

        protected virtual void OnBeforeRender(DX11RenderContext context, PerVisitorRenderTargetComponent pvc) { }
        protected virtual void OnAfterRender(DX11RenderContext context, PerVisitorRenderTargetComponent pvc) { }

        public SampleDescription TrySampleDescription(DX11RenderContext context, SampleDescription sd)
        {
            if (sd.Count > 1 && !context.IsAtLeast101) sd.Count = 1;

            var sds = context.GetMultisampleFormatInfo(DepthFormat);
            var maxlevels = sds[sds.Count - 1].Count;

            if (sd.Count > maxlevels) sd.Count = maxlevels;

            return sd;
        }
        
        public override void Destroy(DX11RenderContext context, bool force, ModularRenderer visitor)
        {
            base.Destroy(context, force, visitor);
            if (PerVisitorComponents.TryGetValue(visitor, out var pvc))
            {
                pvc.Destroy(context);
            }
        }

        public override void Dispose()
        {
            base.Dispose();
            PerVisitorComponents.ForeachConcurrent((v, c) => c.Dispose());
        }
    }
}
