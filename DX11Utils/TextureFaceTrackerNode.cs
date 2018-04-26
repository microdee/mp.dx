using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.ComponentModel.Composition;
using System.Data.SqlTypes;
using VVVV.PluginInterfaces.V1;
using VVVV.PluginInterfaces.V2;
using SlimDX.Direct3D11;
using VVVV.Core.Logging;
using FeralTic.DX11;
using FeralTic.DX11.Resources;
using System.IO;
using System.Reflection;
using FeralTic.DX11.Queries;
using VVVV.DX11;
using mp.dx.Tracking;
using SlimDX.DXGI;
using mp.pddn;
using VVVV.Utils.Animation;
using VVVV.Utils.VMath;
using MapFlags = SlimDX.DXGI.MapFlags;

namespace mp.dx.dx11.Nodes
{
    public enum FaceTrackerMode
    {
        Frontal,
        FrontalSurveillance,
        MultiView,
        MultiViewReinforce
    }
    [PluginInfo(
        Name = "FaceTracker",
        Category = "DX11.Texture",
        Version = "2d",
        Author = "microdee",
        AutoEvaluate = true
        )]
    public class TextureFaceTrackerNode : IPluginEvaluate, IDX11ResourceDataRetriever, IDX11Queryable
    {
        [Input("Texture In")]
        protected Pin<DX11Resource<DX11Texture2D>> FTextureIn;

        [Input("Engine")]
        protected ISpread<FaceTrackerMode> FEngine;
        [Input("Scale", DefaultValue = 1.2)]
        protected ISpread<double> FScale;
        [Input("Min Neighbours", DefaultValue = 2)]
        protected ISpread<int> FMinNeighbours;
        [Input("Min Object Width", DefaultValue = 48)]
        protected ISpread<int> FMinObjWidth;
        [Input("Max Object Width", DefaultValue = 0)]
        protected ISpread<int> FMaxObjWidth;
        [Input("Landmarks", DefaultValue = -1)]
        protected ISpread<int> FDoLandmarks;

        [Input("Enabled")]
        protected ISpread<bool> FEnabled;

        [Output("Output")]
        public ISpread<FaceTrackerContext> FOutput;
        [Output("Query")]
        public ISpread<IDX11Queryable> FQuery;
        [Output("Error")]
        protected ISpread<string> FError;

        [Import()]
        protected IPluginHost FHost;

        [Import()]
        protected ILogger FLogger;

        public DX11RenderContext AssignedContext
        {
            get;
            set;
        }

        Spread<byte[]> ImgCache = new Spread<byte[]>();

        public event DX11RenderRequestDelegate RenderRequest;
        

        public void Evaluate(int SpreadMax)
        {
            this.FError.SliceCount = SpreadMax;
            FOutput.SliceCount = SpreadMax;
            ImgCache.SliceCount = SpreadMax;
            FOutput.Stream.IsChanged = false;

            if (this.FTextureIn.PluginIO.IsConnected)
            {
                if (this.RenderRequest != null) { this.RenderRequest(this, this.FHost); }

                if (this.AssignedContext == null) { this.FError.SliceCount = 0; return; }
                //Do NOT cache this, assignment done by the host
                FQuery[0] = this;
                BeginQuery?.Invoke(AssignedContext);

                for (int i = 0; i < SpreadMax; i++)
                {
                    if (this.FTextureIn[i].Contains(this.AssignedContext) && this.FEnabled[i])
                    {
                        try
                        {
                            if (FOutput[i] == null)
                            {
                                FOutput[i] = new FaceTrackerContext();
                            }

                            FOutput[i].Scale = (float)FScale[i];
                            FOutput[i].MinNeighbors = FMinNeighbours[i];
                            FOutput[i].MinObjectWidth = FMinObjWidth[i];
                            FOutput[i].MaxObjectWidth = FMaxObjWidth[i];
                            FOutput[i].DoLandmarks = FDoLandmarks[i];

                            if (this.FTextureIn[i][this.AssignedContext].Format != Format.R8_UNorm)
                            {
                                FError[i] = "Texture is not R8_UNorm";
                                continue;
                            }

                            int w = this.FTextureIn[i][this.AssignedContext].Width;
                            int h = this.FTextureIn[i][this.AssignedContext].Height;
                            if (ImgCache[i] == null)
                            {
                                ImgCache[i] = new byte[w * h];
                            }
                            if (ImgCache[i].Length != w * h)
                            {
                                ImgCache[i] = new byte[w * h];
                            }
                            var texture = this.FTextureIn[0][AssignedContext];
                            var staging = new DX11StagingTexture2D(AssignedContext, texture.Width, texture.Height, texture.Format);

                            staging.CopyFrom(texture);
                            var db = staging.LockForRead();
                            db.Data.Read(ImgCache[i], 0, w * h);

                            staging.UnLock();
                            staging.Dispose();

                            switch (FEngine[i])
                            {
                                case FaceTrackerMode.Frontal:
                                    FOutput[i].DetectFrontal(ImgCache[i], w, h);
                                    break;
                                case FaceTrackerMode.FrontalSurveillance:
                                    FOutput[i].DetectFrontalSurveillance(ImgCache[i], w, h);
                                    break;
                                case FaceTrackerMode.MultiView:
                                    FOutput[i].DetectMultiView(ImgCache[i], w, h);
                                    break;
                                case FaceTrackerMode.MultiViewReinforce:
                                    FOutput[i].DetectMultiViewReinforce(ImgCache[i], w, h);
                                    break;
                            }

                            this.FError[i] = "";
                        }
                        catch (Exception ex)
                        {
                            FLogger.Log(ex);
                            this.FError[i] = ex.Message + Environment.NewLine + ex.StackTrace;
                        }
                    }
                    else
                    {
                        this.FError[i] = "!";
                    }
                }
                EndQuery?.Invoke(AssignedContext);

                FOutput.Stream.IsChanged = true;
            }
            else
            {
                this.FError.SliceCount = 0;

            }
        }

        public event DX11QueryableDelegate BeginQuery;
        public event DX11QueryableDelegate EndQuery;
    }

    [PluginInfo(
        Name = "FaceTrackerContext",
        Category = "FaceTracker",
        Version = "Split",
        Author = "microdee"
    )]
    public class SplitFaceTrackerContextNode : ObjectSplitNode<FaceTrackerContext> { }

    [PluginInfo(
        Name = "DetectedFace",
        Category = "FaceTracker",
        Version = "Split",
        Author = "microdee"
    )]
    public class SplitDetectedFaceNode : ObjectSplitNode<DetectedFace>
    {
        [Input("Texture Size", AsInt = true, Order = 100)]
        public ISpread<Vector2D> FTexSize;

        [Output("Face Parts Bin Size")]
        public ISpread<int> FParts;

        [Output("Face Parts Looped")]
        public ISpread<bool> FPartLooped;

        private static readonly string[] transformableMembers = {"Width", "Height", "X", "Y", "Angle"};

        public override void OnImportsSatisfiedBegin()
        {
            FParts.AssignFrom(new [] { 17, 10, 9, 6, 6, 12, 8 });
            FPartLooped.AssignFrom(new [] { false, false, false, true, true, true, true });
        }

        public override Type TransformType(Type original, MemberInfo member)
        {
            if (transformableMembers.Any(s => s == member.Name))
                return typeof(double);
            else return original;
        }

        public override object TransformOutput(object obj, MemberInfo member, int i)
        {
            switch (member.Name)
            {
                case "Width":
                {
                    var orig = (int) obj;
                    return ((double) orig / FTexSize[0].x) * 2.0;
                }
                case "Height":
                {
                    var orig = (int)obj;
                    return ((double) orig / FTexSize[0].x) * 2.0;
                }
                case "X":
                {
                    var orig = (int)obj;
                    return VMath.Map((double)orig, 0.0, FTexSize[0].x, -1.0, 1.0, TMapMode.Float);
                }
                case "Y":
                {
                    var orig = (int)obj;
                    return VMath.Map((double)orig, 0.0, FTexSize[0].y, 1.0, -1.0, TMapMode.Float);
                }
                case "Angle":
                {
                    var orig = (int)obj;
                    return (double)orig / 360;
                }
                case "Landmarks":
                {
                    var orig = (Vector2D)obj;
                    return VMath.Map(orig, Vector2D.Zero, FTexSize[0], new Vector2D(-1.0, 1.0), new Vector2D(1.0, -1.0), TMapMode.Float);
                }
                default:
                    return obj;
            }
        }
    }
}
