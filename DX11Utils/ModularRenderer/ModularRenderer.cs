using FeralTic.DX11;
using FeralTic.DX11.Resources;
using System;
using System.Collections.Generic;
using System.ComponentModel.Composition;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using VVVV.DX11;
using VVVV.PluginInterfaces.V2;
using SlimDX.DXGI;
using SlimDX.Direct3D11;
using FeralTic.DX11.Queries;
using SlimDX;

namespace DX11Utils.ModularRenderer
{
    public class ModularRenderer : IDX11RendererHost, IDX11Queryable
    {
        public bool IsEnabled { get; set; }

        public ModularResourceHost BindedResources { get; set; }

        public IModularRenderTarget RenderTarget { get; set; }

        // DONE: port https://github.com/mrvux/dx11-vvvv/blob/368aabdf73bee27ee156e6bfa48dc318768f0643/Core/VVVV.DX11.Lib/Rendering/DepthBufferManager.cs
        // DONE: port https://github.com/mrvux/dx11-vvvv/blob/4d5d99ac7d5d528b5d68086ade4e428c766a2ba4/Core/VVVV.DX11.Lib/Rendering/RenderTargetManager.cs
        // TODO: explicitly manage rendertargets with Depthbuffers, AA and MRT

        public StreamoutResource Streamout { get; set; }

        // TODO: explicitly manage streamouts, and maybe bind them?

        public DX11Resource<DX11Layer> Layer { get; set; }

        public ISpread<Matrix> View { get; set; }
        public ISpread<Matrix> Projection { get; set; }
        public ISpread<Matrix> Aspect { get; set; }
        public ISpread<Matrix> Crop { get; set; }
        public ISpread<Viewport> Viewports { get; set; }

        public event DX11QueryableDelegate BeginQuery;
        public event DX11QueryableDelegate EndQuery;

        public void OnEvaluate()
        {
        }

        public void Destroy(DX11RenderContext context, bool force)
        {
            BindedResources?.Destroy(context, force, this, 0, true);
            RenderTarget.Destroy(context, force, this);
        }

        public void Render(DX11RenderContext context)
        {
            BindedResources?.Render(context, this, 0, true);
        }

        public void Update(DX11RenderContext context)
        {
            BindedResources?.Update(context, this, 0, true);
        }
    }
}
