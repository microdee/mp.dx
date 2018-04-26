using System;
using System.Collections.Generic;
using System.ComponentModel.Composition;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using FeralTic.DX11;
using FeralTic.DX11.Resources;
using SlimDX;
using SlimDX.Direct3D11;
using VVVV.DX11;
using VVVV.DX11.Lib.Rendering;
using VVVV.Nodes.PDDN;
using VVVV.PluginInterfaces.V1;
using VVVV.PluginInterfaces.V2;
using VVVV.Utils.VMath;

namespace DX11Utils
{
    [PluginInfo(
        Name = "Uberer",
        Category = "DX11",
        Author = "microdee",
        AutoEvaluate = false
        )]
    public class UbererNode : ConfigurableDynamicPinNode<string>, IPluginEvaluate, IDisposable, IDX11ResourceHost
    {
        public enum TypeSignature
        {
            Texture1D,
            Texture1DArray,
            Texture2D,
            Texture2DArray,
            Texture3D,
            StructuredBuffer,
            ByteAddressBuffer,
            RawBuffer = 6
        }

        [Import]
        protected IIOFactory FIOFactory;

        [Config("Rendertarget Count")]
        protected IDiffSpread<int> FRenderTargetCount;
        [Config("Depth Mode")]
        protected IDiffSpread<eDepthBufferMode> FDepthMode;
        [Config("StreamOut Count")]
        protected IDiffSpread<int> FStreamOutCount;
        [Config("Attached Resources")]
        protected IDiffSpread<string> FAttachedResources;

        [Input("Element Count", DefaultValue = -1, Order = 100)]
        protected ISpread<int> FElCount;
        [Input("Immutable", DefaultValue = 0, Order = 102)]
        protected ISpread<bool> FImmut;
        [Input("Keep In Memory", DefaultValue = 0, Order = 103)]
        protected ISpread<bool> FKeep;
        [Input("Apply", IsBang = true, DefaultValue = 1, Order = 104)]
        protected ISpread<bool> FApply;

        [Output("Buffer")]
        protected ISpread<DX11Resource<IDX11ReadableStructureBuffer>> FOutput;
        [Output("Is Valid")]
        protected ISpread<bool> FValid;

        private PinDictionary Pd;
        protected List<string> PrevPins = new List<string>();
        private int elstrides = 4;
        private int elcount = 0;

        private MemoryStream FInData = new MemoryStream();
        private byte[] immutbuf;

        private bool FInvalidate;
        private bool FFirst = true;

        protected override bool IsConfigDefault()
        {
            return FAttachedResources[0] == "";
        }

        protected override void PreInitialize()
        {
            Pd = new PinDictionary(FIOFactory);
        }

        protected override void OnConfigPinChanged()
        {

        }

        public void Evaluate(int SpreadMax)
        {

        }

        public void Update(DX11RenderContext context)
        {

        }

        public void Destroy(DX11RenderContext context, bool force)
        {
            if (force || !FKeep[0])
            {
                FOutput[0].Dispose(context);
            }
        }

        public void Dispose()
        {
            try
            {
                FOutput[0]?.Dispose();
            }
            catch { }
        }
    }
}
