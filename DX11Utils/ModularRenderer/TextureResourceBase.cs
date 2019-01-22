using FeralTic.DX11;
using FeralTic.DX11.Resources;
using SlimDX;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DX11Utils.ModularRenderer
{
    public abstract class TextureResourceBase<TRes> : ModularResourceBase<TRes> where TRes : IDX11Resource
    {
        public bool Clear { get; set; }

        public Color4 ClearColor { get; set; }

        public int Width { get; set; }

        public int Height { get; set; }

        public SlimDX.DXGI.Format Format { get; set; }

        public List<string> AllowedFormats { get; } =
            DX11EnumFormatHelper.NullDeviceFormats.GetAllowedFormats(SlimDX.Direct3D11.FormatSupport.RenderTarget);


    }
}
