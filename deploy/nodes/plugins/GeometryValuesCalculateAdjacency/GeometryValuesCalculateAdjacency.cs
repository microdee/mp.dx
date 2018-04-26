#region usings
using System;
using System.ComponentModel.Composition;
using System.Collections.Generic;

using VVVV.PluginInterfaces.V1;
using VVVV.PluginInterfaces.V2;
using VVVV.Utils.VColor;
using VVVV.Utils.VMath;

using VVVV.Core.Logging;
#endregion usings

namespace VVVV.Nodes
{
	#region PluginInfo
	[PluginInfo(Name = "CalculateAdjacency", Category = "Values", Version = "Geometry", Tags = "")]
	#endregion PluginInfo
	public class GeometryValuesCalculateAdjacencyNode : IPluginEvaluate
	{
		#region fields & pins
		[Input("Vertices Count")]
		public ISpread<int> FVerts;
		[Input("Indices")]
		public ISpread<int> FIndices;
		[Input("Reinit", IsBang = true)]
		public ISpread<bool> FInit;

		[Output("Output")]
		public ISpread<ISpread<int>> FOutput;

		[Import()]
		public ILogger FLogger;
		#endregion fields & pins

		public void Evaluate(int SpreadMax)
		{
            if (FInit[0])
            {
				FOutput.SliceCount = FVerts[0];
                for (int i = 0; i < FOutput.SliceCount; i++)
                {
                    FOutput[i].SliceCount = 0;
                }
                for (int i = 0; i < FIndices.SliceCount; i++)
                {
                    FOutput[FIndices[i]].Add(i);
                }
            }
		}
	}
}
