using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
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
    public class PerVisitorRenderTarget2D : PerVisitorRenderTargetComponent
    {
        public PerVisitorRenderTarget2D(IModularRenderTarget parent) : base(parent) { }

        protected override IDX11DepthStencil CreateDepthStencil(DX11RenderContext context)
        {
            return new DX11DepthStencil(
                context,
                Parent.Width, Parent.Height,
                Parent.TrySampleDescription(context, Parent.SampleDescription),
                Parent.DepthFormat);
        }

        [VvvvIgnore]
        public ConcurrentDictionary<DX11RenderContext, DX11GraphicsRenderer> Renderers { get; } =
            new ConcurrentDictionary<DX11RenderContext, DX11GraphicsRenderer>();
    }

    public class ModularRenderTarget2D : ModularRenderTarget<DX11Texture2D>
    {
        protected override PerVisitorRenderTargetComponent CreatePerVisitorComponent()
        {
            return new PerVisitorRenderTarget2D(this);
        }

        public override IDX11RWResource GetMainTarget(DX11RenderContext device, ModularRenderer visitor)
        {
            return null;
        }

        protected override void OnUpdate(DX11RenderContext context, PerVisitorRenderTargetComponent pvc)
        {
            base.OnUpdate(context, pvc);
            if (pvc is PerVisitorRenderTarget2D pvc2d) pvc2d.Renderers.GetOrAdd(context, c => new DX11GraphicsRenderer(c));
        }

        protected override void OnBeforeRender(DX11RenderContext context, PerVisitorRenderTargetComponent pvc)
        {
            if (pvc is PerVisitorRenderTarget2D pvc2d)
            {
                var renderer = pvc2d.Renderers[context];
                renderer.SetTargets();
            }
        }

        protected override void OnAfterRender(DX11RenderContext context, PerVisitorRenderTargetComponent pvc)
        {
            if (pvc is PerVisitorRenderTarget2D pvc2d)
            {
                var renderer = pvc2d.Renderers[context];
                renderer.CleanTargets();
            }
        }

        protected override void DoClear(DX11RenderContext context, PerVisitorRenderTargetComponent pvc)
        {
            if (Clear && pvc is PerVisitorRenderTarget2D pvc2d)
            {
                var renderer = pvc2d.Renderers[context];
                renderer.Clear(ClearColor);
            }
        }

        protected override DX11Resource<DX11Texture2D> CreateResource(DX11RenderContext context)
        {
            throw new NotImplementedException();
        }

        protected override DX11Texture2D CreateContextResource(DX11RenderContext context)
        {
            throw new NotImplementedException();
        }
    }
}
