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

namespace DX11Utils.ModularRenderer
{
    public interface IModularResourceBase : IDisposable
    {
        IDX11RenderSemantic UavSemantic { get; set; }

        IDX11RenderSemantic SrvSemantic { get; set; }

        bool Reset { get; set; }

        bool IsEnabled { get; set; }

        ModularResourceHost Host { get; set; }

        void OnEvaluate(ModularRenderer visitor);
        void Render(DX11RenderContext context, ModularRenderer visitor);
        void Update(DX11RenderContext context, ModularRenderer visitor);
        void Destroy(DX11RenderContext context, bool force, ModularRenderer visitor);
    }

    public abstract class ModularResourceBase : OperationBase, IModularResourceBase
    {
        public IDX11RenderSemantic UavSemantic { get; set; }

        public IDX11RenderSemantic SrvSemantic { get; set; }

        public bool Reset { get; set; }

        public virtual bool IsEnabled { get; set; }

        public ModularResourceHost Host { get; set; }

        public override void Invoke() { }

        public virtual void OnEvaluate(ModularRenderer visitor)
        {
        }

        public virtual void Render(DX11RenderContext context, ModularRenderer visitor)
        {
            if (!visitor.IsEnabled && !IsEnabled) return;
            if (Reset) Update(context, visitor);
        }

        public virtual void Update(DX11RenderContext context, ModularRenderer visitor)
        {
        }

        public virtual void Destroy(DX11RenderContext context, bool force, ModularRenderer visitor)
        {
        }

        public virtual void Dispose()
        {
            UavSemantic.Dispose();
            SrvSemantic.Dispose();
        }
    }

    public abstract class ModularResourceBase<TRes> : ModularResourceBase where TRes : IDX11Resource
    {
        public ConcurrentDictionary<ModularRenderer, DX11Resource<TRes>> Resources { get; } =
            new ConcurrentDictionary<ModularRenderer, DX11Resource<TRes>>();

        protected abstract DX11Resource<TRes> CreateResource(DX11RenderContext context);
        protected abstract TRes CreateContextResource(DX11RenderContext context);

        protected virtual DX11Resource<TRes> GetVisitorResource(DX11RenderContext context, ModularRenderer visitor) =>
            Resources.GetOrAdd(visitor, v => CreateResource(context));

        public override void Dispose()
        {
            base.Dispose();
            Resources.ForeachConcurrent((k, v) => v.Dispose());
        }
    }

    public class ModularResourceHost : OperationHost<ModularResourceBase>, IDisposable
    {
        private void InvokeR(int i, int j, Action<int, int, ModularResourceBase> action) => Invoke(i, j, (oi, oj, op) =>
        {
            op.Host = this;
            action?.Invoke(oi, oj, op);
        });

        private void InvokeR(int i, Action<int, int, ModularResourceBase> action) => Invoke(i, (oi, oj, op) =>
        {
            op.Host = this;
            action?.Invoke(oi, oj, op);
        });

        public void SetEnabled(bool val, int i, int j, bool r = false)
        {
            if (r && Child is ModularResourceHost rh) rh.SetEnabled(val, i, j, true);
            InvokeR(i, j, (oi, oj, op) => op.IsEnabled = val);
        }
        public void SetEnabled(bool val, int i, bool r = false)
        {
            if (r && Child is ModularResourceHost rh) rh.SetEnabled(val, i, true);
            InvokeR(i, (oi, oj, op) => op.IsEnabled = val);
        }

        public void OnEvaluate(ModularRenderer visitor, int i, int j, bool r = false)
        {
            if (r && Child is ModularResourceHost rh) rh.OnEvaluate(visitor, i, j, true);
            InvokeR(i, j, (oi, oj, op) => op.OnEvaluate(visitor));
        }
        public void OnEvaluate(ModularRenderer visitor, int i, bool r = false)
        {
            if (r && Child is ModularResourceHost rh) rh.OnEvaluate(visitor, i, true);
            InvokeR(i, (oi, oj, op) => op.OnEvaluate(visitor));
        }

        public void Render(DX11RenderContext context, ModularRenderer visitor, int i, int j, bool r = false)
        {
            if (r && Child is ModularResourceHost rh) rh.Render(context, visitor, i, j, true);
            InvokeR(i, j, (oi, oj, op) => op.Render(context, visitor));
        }
        public void Render(DX11RenderContext context, ModularRenderer visitor, int i, bool r = false)
        {
            if (r && Child is ModularResourceHost rh) rh.Render(context, visitor, i, true);
            InvokeR(i, (oi, oj, op) => op.Render(context, visitor));
        }

        public void Update(DX11RenderContext context, ModularRenderer visitor, int i, int j, bool r = false)
        {
            if (r && Child is ModularResourceHost rh) rh.Update(context, visitor, i, j, true);
            InvokeR(i, j, (oi, oj, op) => op.Update(context, visitor));
        }
        public void Update(DX11RenderContext context, ModularRenderer visitor, int i, bool r = false)
        {
            if (r && Child is ModularResourceHost rh) rh.Update(context, visitor, i, true);
            InvokeR(i, (oi, oj, op) => op.Update(context, visitor));
        }

        public void Destroy(DX11RenderContext context, bool force, ModularRenderer visitor, int i, int j, bool r = false)
        {
            if (r && Child is ModularResourceHost rh) rh.Destroy(context, force, visitor, i, j, true);
            InvokeR(i, j, (oi, oj, op) => op.Destroy(context, force, visitor));
        }
        public void Destroy(DX11RenderContext context, bool force, ModularRenderer visitor, int i, bool r = false)
        {
            if (r && Child is ModularResourceHost rh) rh.Destroy(context, force, visitor, i, true);
            InvokeR(i, (oi, oj, op) => op.Destroy(context, force, visitor));
        }

        public void CollectSemantics(List<IDX11RenderSemantic> target, int i, bool r = false)
        {
            if (r && Child is ModularResourceHost rh) rh.CollectSemantics(target, i, true);
            for(int j=0; j<Operations[i].SliceCount; j++)
            {
                target.Add(Operations[i][j].SrvSemantic);
                target.Add(Operations[i][j].UavSemantic);
            }
        }

        public void Dispose()
        {
            (Child as ModularResourceHost)?.Dispose();
            for (int i=0; i < Operations.SliceCount; i++)
            {
                InvokeR(i, (oi, oj, op) => op.Dispose());
            }
        }
    }
}
