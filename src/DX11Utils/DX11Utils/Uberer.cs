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
    public class UbererNode : IPluginEvaluate, IDisposable, IDX11ResourceHost
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
        public class TypeDesc
        {
            public TypeDesc(Type pt, TypeSignature ts, int b)
            {
                PinType = pt;
                TypeSig = ts;
                Size = b;
            }
            public Type PinType;
            public TypeSignature TypeSig;
            public int Size;
        }

        public static List<TypeDesc> TypeMap = new List<TypeDesc>
        {
            new TypeDesc(typeof(float), TypeSignature.Float, 4),
            new TypeDesc(typeof(Vector2D), TypeSignature.Float2, 8),
            new TypeDesc(typeof(Vector3D), TypeSignature.Float3, 12),
            new TypeDesc(typeof(Vector4D), TypeSignature.Float4, 16),
            new TypeDesc(typeof(uint), TypeSignature.Uint, 4),
            new TypeDesc(typeof(Vector2D), TypeSignature.Uint2, 8),
            new TypeDesc(typeof(Vector3D), TypeSignature.Uint3, 12),
            new TypeDesc(typeof(Vector4D), TypeSignature.Uint4, 16),
            new TypeDesc(typeof(Matrix4x4), TypeSignature.Float4x4, 64)
        };

        [Import]
        protected IIOFactory FIOFactory;

        [Config("Rendertarget Count")]
        protected IDiffSpread<int> FRenderTargetCount;
        [Config("Depth Mode")]
        protected IDiffSpread<eDepthBufferMode> FDepthMode;
        [Config("Depth Mode")]
        protected IDiffSpread<> FDepthMode;
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
            return FLayout[0] == "";
        }

        protected override void PreInitialize()
        {
            Pd = new PinDictionary(FIOFactory);
            ConfigPinCopy = FLayout;
        }

        protected override void OnConfigPinChanged()
        {
            var pinlayout = FLayout[0].Trim().Split(',');
            pinlayout = pinlayout.Select(curr => curr.Trim()).ToArray();
            var typenamepairs = pinlayout.Select(s => s.Split(' ')).Select(pair => new Tuple<string, string>(pair[0], pair[1]));
            foreach (var pair in typenamepairs)
            {
                if (!Pd.InputPins.ContainsKey(pair.Item2)) continue;
                if (((TypeDesc) Pd.InputPins[pair.Item2].CustomData).TypeSig.ToString().Equals(pair.Item1, StringComparison.InvariantCultureIgnoreCase)) continue;
                Pd.RemoveInput(pair.Item2);
            }
            foreach (var pin in Pd.InputPins.Keys)
            {
                if(typenamepairs.Any(curr => curr.Item2 == pin)) continue;
                Pd.RemoveInput(pin);
            }
            foreach (var pair in typenamepairs)
            {
                if(Pd.InputPins.ContainsKey(pair.Item2)) continue;
                try
                {
                    TypeSignature typesig;
                    Enum.TryParse(pair.Item1.ToUpperFirstInvariant(), out typesig);
                    var typedesc = TypeMap[(int)typesig];
                    Pd.AddInput(typedesc.PinType, new InputAttribute(pair.Item2)
                    {
                        AsInt = pair.Item1.Contains("uint", StringComparison.InvariantCultureIgnoreCase),
                        AutoValidate = false
                    }, typedesc);
                }
                catch (Exception e) { }
            }
            FFirst = true;
        }

        public void Evaluate(int SpreadMax)
        {
            FInvalidate = false;

            if (FApply[0] || FFirst)
            {
                elstrides = 0;
                elcount = FElCount[0] < 0 ? Pd.InputSpreadMax : FElCount[0];
                foreach (var pin in Pd.InputPins.Values)
                {
                    pin.Spread.Sync();
                    elstrides += ((TypeDesc) pin.CustomData).Size;
                }
                FOutput.SliceCount = 1;
                FValid.SliceCount = 1;
                if (FOutput[0] == null) FOutput[0] = new DX11Resource<IDX11ReadableStructureBuffer>();
                FInData.SetLength(0);
                for (int i = 0; i < elcount; i++)
                {
                    foreach (var pin in Pd.InputPins.Values)
                    {
                        switch (((TypeDesc)pin.CustomData).TypeSig)
                        {
                            case TypeSignature.Float:
                                var valf = (float) pin.Spread[i];
                                FInData.Write(BitConverter.GetBytes(valf), 0, 4);
                                break;
                            case TypeSignature.Uint:
                                var valu = (uint)pin.Spread[i];
                                FInData.Write(BitConverter.GetBytes(valu), 0, 4);
                                break;
                            case TypeSignature.Float2:
                                var valf2 = (Vector2D)pin.Spread[i];
                                FInData.Write(BitConverter.GetBytes((float)valf2.x), 0, 4);
                                FInData.Write(BitConverter.GetBytes((float)valf2.y), 0, 4);
                                break;
                            case TypeSignature.Float3:
                                var valf3 = (Vector3D)pin.Spread[i];
                                FInData.Write(BitConverter.GetBytes((float)valf3.x), 0, 4);
                                FInData.Write(BitConverter.GetBytes((float)valf3.y), 0, 4);
                                FInData.Write(BitConverter.GetBytes((float)valf3.z), 0, 4);
                                break;
                            case TypeSignature.Float4:
                                var valf4 = (Vector4D)pin.Spread[i];
                                FInData.Write(BitConverter.GetBytes((float)valf4.x), 0, 4);
                                FInData.Write(BitConverter.GetBytes((float)valf4.y), 0, 4);
                                FInData.Write(BitConverter.GetBytes((float)valf4.z), 0, 4);
                                FInData.Write(BitConverter.GetBytes((float)valf4.w), 0, 4);
                                break;
                            case TypeSignature.Uint2:
                                var valu2 = (Vector2D)pin.Spread[i];
                                FInData.Write(BitConverter.GetBytes((uint)Math.Floor(valu2.x)), 0, 4);
                                FInData.Write(BitConverter.GetBytes((uint)Math.Floor(valu2.y)), 0, 4);
                                break;
                            case TypeSignature.Uint3:
                                var valu3 = (Vector3D)pin.Spread[i];
                                FInData.Write(BitConverter.GetBytes((uint)Math.Floor(valu3.x)), 0, 4);
                                FInData.Write(BitConverter.GetBytes((uint)Math.Floor(valu3.y)), 0, 4);
                                FInData.Write(BitConverter.GetBytes((uint)Math.Floor(valu3.z)), 0, 4);
                                break;
                            case TypeSignature.Uint4:
                                var valu4 = (Vector4D)pin.Spread[i];
                                FInData.Write(BitConverter.GetBytes((uint)Math.Floor(valu4.x)), 0, 4);
                                FInData.Write(BitConverter.GetBytes((uint)Math.Floor(valu4.y)), 0, 4);
                                FInData.Write(BitConverter.GetBytes((uint)Math.Floor(valu4.z)), 0, 4);
                                FInData.Write(BitConverter.GetBytes((uint)Math.Floor(valu4.w)), 0, 4);
                                break;
                            case TypeSignature.Float4x4:
                                var valm = (Matrix4x4)pin.Spread[i];
                                valm = valm.Transpose();
                                foreach (var c in valm.Values)
                                    FInData.Write(BitConverter.GetBytes((float)c), 0, 4);
                                break;
                            default:
                                throw new ArgumentOutOfRangeException();
                        }
                    }
                }

                FInvalidate = true;
                FFirst = false;
                FOutput.Stream.IsChanged = true;
            }
        }

        public void Update(DX11RenderContext context)
        {
            if (FInvalidate || !FOutput[0].Contains(context) || FElCount.IsChanged || FImmut.IsChanged)
            {
                if (FOutput[0].Contains(context))
                {
                    if (FOutput[0][context].ElementCount != elcount)
                    {
                        FOutput[0].Dispose(context);
                    }
                }
                else
                {
                    if (FImmut[0])
                    {
                        FInData.Position = 0;
                        FInData.Read(immutbuf, 0, (int)FInData.Length);
                        var ds = new DataStream(immutbuf, true, true);
                        ds.Position = 0;
                        FOutput[0][context] = new DX11ImmutableStructuredBuffer(context.Device, elcount, elstrides, ds);
                    }
                    else
                    {
                        FOutput[0][context] = new DX11DynamicStructuredBuffer(context.Device, elcount, elstrides);
                    }
                    FValid[0] = true;
                }

                var b = FOutput[0][context];
                try
                {
                    if (FImmut[0])
                    {
                        if (FOutput[0][context] != null) FOutput[0][context].Dispose();
                        FInData.Position = 0;
                        FInData.Read(immutbuf, 0, (int)FInData.Length);
                        var ds = new DataStream(immutbuf, true, true);
                        ds.Position = 0;
                        FOutput[0][context] = new DX11ImmutableStructuredBuffer(context.Device, elcount, elstrides, ds);
                    }
                    else
                    {
                        var db = context.CurrentDeviceContext.MapSubresource(b.Buffer, MapMode.WriteDiscard,
                            MapFlags.None);
                        db.Data.Position = 0;
                        FInData.Position = 0;
                        FInData.CopyTo(db.Data);
                        db.Data.Position = 0;
                        context.CurrentDeviceContext.UnmapSubresource(b.Buffer, 0);
                    }
                }
                catch
                {
                    FValid[0] = false;
                }
            }
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
