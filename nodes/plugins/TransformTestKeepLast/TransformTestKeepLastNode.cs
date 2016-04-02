#region usings
using System;
using System.Collections.Generic;
using System.ComponentModel.Composition;

using VVVV.PluginInterfaces.V1;
using VVVV.PluginInterfaces.V2;
using VVVV.Utils.VColor;
using VVVV.Utils.VMath;

using VVVV.Core.Logging;
#endregion usings

namespace VVVV.Nodes
{
	public abstract class KeepLastNode<T> : IPluginEvaluate
	{
		#region fields & pins
		[Input("Input")]
		public ISpread<ISpread<T>> FInput;
		[Input("Default")]
		public ISpread<T> FDef;
		[Input("Reset", IsBang = true)]
		public ISpread<bool> FReset;

		[Output("Output")]
		public ISpread<ISpread<T>> FOutput;
		[Output("Has Value")]
		public ISpread<bool> FHasValue;
		[Output("Is NIL")]
		public ISpread<bool> FIsNIL;

		[Import()]
		public ILogger FLogger;
		#endregion fields & pins

		//called when data for any output pin is requested
		public void Evaluate(int SpreadMax)
		{
			FOutput.SliceCount = FInput.SliceCount;
			FHasValue.SliceCount = FInput.SliceCount;
			for (int i = 0; i < FInput.SliceCount; i++) {
				if (FReset[i]) {
					FHasValue[i] = false;
				}
				if (!FHasValue[i]) {
					FOutput[i].SliceCount = 1;
					FOutput[i][0] = FDef[i];
				}
				if (FInput[i].SliceCount != 0) {
					FHasValue[i] = true;
					FIsNIL[i] = false;
					FOutput[i].SliceCount = FInput[i].SliceCount;
					for (int j = 0; j < FInput[i].SliceCount; j++) {
						FOutput[i][j] = FInput[i][j];
					}
				} else {
					FIsNIL[i] = true;
				}
			}
		}
	}

	// Miss a type? Can you see the pattern here? ;)

	public class ValueKeepLastNode : KeepLastNode<double>
	{
	}

	public class StringKeepLastNode : KeepLastNode<string>
	{
	}

	[PluginInfo(Name = "TestKeepLast", Category = "Transform", Tags = "")]
	public class TransformTestKeepLastNode : KeepLastNode<Matrix4x4>
	{
	}
}
