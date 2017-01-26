using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using FeralTic.DX11.Resources;
using VVVV.DX11;
using VVVV.Packs.Messaging;

namespace VVVV.Nodes
{
    class DX11Types : TypeProfile
    {
        public TypeRecord<DX11Resource<IDX11ReadableResource>> ReadableResource = new TypeRecord<DX11Resource<IDX11ReadableResource>>("ReadableResource", CloneBehaviour.Null, () => null);
    }
}