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
using VVVV.DX11;
using VVVV.PluginInterfaces.V2.Graph;
using VVVV.DX11.Lib.Rendering;

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
    public abstract class ModularRenderTarget<TRes> : TextureResourceBase<TRes> where TRes : IDX11Resource
    {
        private SlimDX.DXGI.Format _depthFormat;

        public AaSampleCount AaSamplesPerPixel { get; set; }

        public eDepthBufferMode DepthBufferUsageMode { get; set; }

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
        
        public DX11Resource<DX11DepthStencil> DepthInput { get; set; }

        public ConcurrentDictionary<ModularRenderer, DX11Resource<DX11DepthStencil>> DepthOutput { get; } =
            new ConcurrentDictionary<ModularRenderer, DX11Resource<DX11DepthStencil>>();

        [VvvvIgnore]
        public ConcurrentDictionary<ModularRenderer, DX11Resource<DX11WriteOnlyDepthStencil>> WriteOnlyDepth { get; } =
            new ConcurrentDictionary<ModularRenderer, DX11Resource<DX11WriteOnlyDepthStencil>>();


    }

}
