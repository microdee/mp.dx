using System;
using System.Collections.Generic;
using System.ComponentModel.Composition;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using FeralTic.DX11;
using FeralTic.DX11.Resources;
using SlimDX;
using SlimDX.Direct3D11;
using VVVV.DX11;
using VVVV.PluginInterfaces.V1;
using VVVV.PluginInterfaces.V2;

namespace mp.dx.dx11.Nodes
{
    [PluginInfo(
        Name = "DynamicBuffer",
        Category = "DX11.Buffer",
        Version = "Custom",
        Author = "microdee",
        AutoEvaluate = false
        )]
    public class CustomDynamicStructuredBuffer : IPluginEvaluate, IDisposable, IDX11ResourceHost
    {
        [Input("Data", DefaultValue = 0, AutoValidate = false, Order = 5)]
        protected ISpread<Stream> FInData;
        [Input("Element Count", DefaultValue = 1, Order = 6)]
        protected ISpread<int> FElCount;
        [Input("Strides", DefaultValue = 4, Order = 7)]
        protected ISpread<int> FElStrides;
        [Input("Immutable", DefaultValue = 0, Order = 8)]
        protected ISpread<bool> FImmut;
        [Input("Keep In Memory", DefaultValue = 0, Order = 9)]
        protected ISpread<bool> FKeep;
        [Input("Apply", IsBang = true, DefaultValue = 1, Order = 10)]
        protected ISpread<bool> FApply;

        [Output("Buffer")]
        protected ISpread<DX11Resource<IDX11ReadableStructureBuffer>> FOutput;
        [Output("Is Valid")]
        protected ISpread<bool> FValid;

        private byte[] immutbuf;
        
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
                        if (FOutput[i] == null) { FOutput[i] = new DX11Resource<IDX11ReadableStructureBuffer>(); }
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

        public void Update(DX11RenderContext context)
        {
            if (FInData.SliceCount == 0) { return; }
            for (int i = 0; i < FOutput.SliceCount; i++)
            {
                if (FInvalidate || !FOutput[i].Contains(context) || FElCount.IsChanged || FElStrides.IsChanged || FImmut.IsChanged)
                {
                    if (FOutput[i].Contains(context))
                    {
                        if (FOutput[i][context].ElementCount != FElCount[i])
                        {
                            FOutput[i].Dispose(context);
                        }
                    }
                    else
                    {
                        if (FInData[i].Length > 0)
                        {
                            if (FImmut[i])
                            {
                                FInData[i].Position = 0;
                                FInData[i].Read(immutbuf, 0, (int)FInData[i].Length);
                                var ds = new DataStream(immutbuf, true, true);
                                ds.Position = 0;
                                FOutput[i][context] = new DX11ImmutableStructuredBuffer(context.Device, FElCount[i], FElStrides[i], ds);
                            }
                            else
                            {
                                FOutput[i][context] = new DX11DynamicStructuredBuffer(context.Device, FElCount[i], FElStrides[i]);
                            }
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
                        if (FImmut[i])
                        {
                            if (FOutput[i][context] != null) FOutput[i][context].Dispose();
                            FInData[i].Position = 0;
                            FInData[i].Read(immutbuf, 0, (int)FInData[i].Length);
                            var ds = new DataStream(immutbuf, true, true);
                            ds.Position = 0;
                            FOutput[i][context] = new DX11ImmutableStructuredBuffer(context.Device, FElCount[i], FElStrides[i], ds);
                        }
                        else
                        {
                            var db = context.CurrentDeviceContext.MapSubresource(b.Buffer, MapMode.WriteDiscard,
                                MapFlags.None);
                            db.Data.Position = 0;
                            FInData[i].Position = 0;
                            FInData[i].CopyTo(db.Data);
                            db.Data.Position = 0;
                            context.CurrentDeviceContext.UnmapSubresource(b.Buffer, 0);
                        }
                    }
                    catch
                    {
                        FValid[i] = false;
                    }
                }
            }
        }

        public void Destroy(DX11RenderContext context, bool force)
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
