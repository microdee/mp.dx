
using SlimDX.Direct3D11;
using SlimDX.DXGI;
using System;
using FeralTic.DX11;
using FeralTic.DX11.Resources;
using VVVV.DX11.Lib.Rendering;

namespace mp.dx.dx11.Resources
{
    public class DX11RWTextureArray2D : DX11TextureArray2D, IDX11RWResource
    {
        public DX11RWTextureArray2D(DX11RenderContext context, Texture2D resource) : base(context, resource)
        {
            var uavd = new UnorderedAccessViewDescription()
            {
                ArraySize = this.desc.ArraySize,
                FirstArraySlice = 0,
                Dimension = UnorderedAccessViewDimension.Texture2DArray,
                Format = this.desc.Format,
                DepthSliceCount = 1,
                FirstDepthSlice = 0,
                ElementCount = desc.ArraySize,
                FirstElement = 0

            };
            UAV = new UnorderedAccessView(context.Device, resource, uavd);
        }

        public UnorderedAccessView UAV { get; }
    }
    public class RWTexture2dArrayRenderSemantic : DX11RenderSemantic<DX11RWTextureArray2D>
    {
        public RWTexture2dArrayRenderSemantic(string semantic, bool mandatory) : base(semantic, mandatory) { TypeNames = new string[] { "RWTexture2DArray" }; }
        protected override void ApplyVariable(string name, DX11ShaderInstance instance) { instance.SetByName(name, this.Data != null ? this.Data.UAV : null); }
    }
}
