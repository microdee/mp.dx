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
	public class JointNode
	{
		public string Name = "";
		public Matrix4x4 Transform = new Matrix4x4();
		public List<JointNode> Children = new List<JointNode>();
		
		public JointNode(string name)
		{
			this.Name = name;
		}
		
		public JointNode(string name, params JointNode[] children)
		{
			this.Name = name;
			foreach(JointNode c in children)
			{
				this.Children.Add(c);
			}
		}
	}
	#region PluginInfo
	[PluginInfo(Name = "GetJointRelativeTransform", Category = "Kinect2", Help = "Basic template with one transform in/out", Tags = "matrix")]
	#endregion PluginInfo
	public class Kinect2GetJointRelativeTransformNode : IPluginEvaluate
	{
		#region fields & pins
		[Input("Input")]
		public ISpread<Matrix4x4> FInput;

		[Output("Output")]
		public ISpread<Matrix4x4> FOutput;

		[Import()]
		public ILogger FLogger;
		
		[ImportingConstructor]
		public Kinect2GetJointRelativeTransformNode() {
			
		}
		#endregion fields & pins

		//called when data for any output pin is requested
		public void Evaluate(int SpreadMax)
		{
			FOutput.SliceCount = SpreadMax;

			for (int i = 0; i < SpreadMax; i++)
				FOutput[i] = FInput[i] * VMath.Scale(2, 2, 2);

			//FLogger.Log(LogType.Debug, "Logging to Renderer (TTY)");
		}
	}
}
