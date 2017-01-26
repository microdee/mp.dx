using System;
using System.Collections.Generic;
using System.ComponentModel.Composition;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using FeralTic.DX11;
using FeralTic.DX11.Resources;
using SlimDX.Direct3D11;
using VVVV.DX11;
using VVVV.PluginInterfaces.V1;
using VVVV.PluginInterfaces.V2;

namespace DX11Utils
{
    [PluginInfo(
        Name = "DynamicBuffer",
        Category = "DX11.RawBuffer",
        Author = "microdee",
        AutoEvaluate = false
        )]
    public class DynamicRawBuffer : IPluginEvaluate, IDisposable, IDX11ResourceProvider
    {
        [Input("Data", DefaultValue = 0, AutoValidate = false, Order = 5)]
        protected ISpread<Stream> FInData;
        [Input("Keep In Memory", DefaultValue = 0, Order = 6)]
        protected ISpread<bool> FKeep;
        [Input("Apply", IsBang = true, DefaultValue = 1, Order = 7)]
        protected ISpread<bool> FApply;

        [Output("Buffer")]
        protected ISpread<DX11Resource<DX11DynamicRawBuffer>> FOutput;
        [Output("Is Valid")]
        protected ISpread<bool> FValid;

        private bool FInvalidate;
        private bool FFirst = true;

        public void Evaluate(int SpreadMax)
        {
            FInvalidate = false;

            if (FApply[0] || FFirst)
            {
                FInData.Sync();

                if (FInData.SliceCount > 0)
                {
                    if (FInData.SliceCount < FOutput.SliceCount)
                    {
                        for (int i = FInData.SliceCount; i < FOutput.SliceCount; i++)
                        {
                            if (FOutput[i] != null) FOutput[i].Dispose();
                        }
                    }
                    FOutput.SliceCount = FInData.SliceCount;
                    FValid.SliceCount = FInData.SliceCount;
                    for (int i = 0; i < FInData.SliceCount; i++)
                    {
                        if (FOutput[i] == null) { FOutput[i] = new DX11Resource<DX11DynamicRawBuffer>(); }
                    }
                }
                else
                {
                    if (FOutput.SliceCount > 0)
                    {
                        for (int i = 0; i < FOutput.SliceCount; i++)
                        {
                            if (FOutput[i] != null) FOutput[i].Dispose();
                        }
                    }
                    FOutput.SliceCount = 0;
                    FValid.SliceCount = 0;
                }

                FInvalidate = true;
                FFirst = false;
                FOutput.Stream.IsChanged = true;
            }
        }

        public void Update(IPluginIO pin, DX11RenderContext context)
        {
            if (FInData.SliceCount == 0) { return; }
            for (int i = 0; i < FOutput.SliceCount; i++)
            {
                int bablength = (int)(Math.Ceiling(FInData[i].Length / 4.0)*4);
                if (FInvalidate || !FOutput[i].Contains(context))
                {
                    if (FOutput[i].Contains(context))
                    {
                        if (FOutput[i][context].Size != bablength)
                        {
                            FOutput[i].Dispose(context);
                        }
                    }

                    if (!FOutput[i].Contains(context))
                    {
                        if (FInData[i].Length > 0)
                        {
                            FOutput[i][context] = new DX11DynamicRawBuffer(context.Device, bablength);
                            FValid[i] = true;
                        }
                        else
                        {
                            FValid[i] = false;
                            continue;
                        }
                    }

                    var b = FOutput[i][context];

                    try
                    {
                        var db = context.CurrentDeviceContext.MapSubresource(b.Buffer, MapMode.WriteDiscard, MapFlags.None);
                        db.Data.Position = 0;
                        FInData[i].Position = 0;
                        FInData[i].CopyTo(db.Data);
                        db.Data.Position = 0;
                        context.CurrentDeviceContext.UnmapSubresource(b.Buffer, 0);
                    }
                    catch
                    {
                        FValid[i] = false;
                    }
                }
            }
        }

        public void Destroy(IPluginIO pin, DX11RenderContext context, bool force)
        {
            if (force || !FKeep[0])
            {
                for(int i=0; i<FOutput.SliceCount; i++)
                    FOutput[i].Dispose(context);
            }
        }

        public void Dispose()
        {
            try
            {
                for (int i = 0; i < FOutput.SliceCount; i++)
                {
                    if (FOutput.SliceCount > 0)
                        FOutput[i]?.Dispose();
                }

            }
            catch
            {

            }
        }
    }
}
