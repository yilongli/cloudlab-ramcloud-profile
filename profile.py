"""
Testing repo-based profile

Instructions:
    TODO
"""

import geni.portal as portal
import geni.rspec.pg as RSpec
import geni.urn as urn
import geni.aggregate.cloudlab as cloudlab

pc = portal.Context()

images = [ ("UBUNTU18-64-STD", "Ubuntu 18.04") ]

types = [ ("m510", "m510 (Intel Xeon-D 1548 8 cores@2.0Ghz, Mellanox CX3 10GbE)"),
          ("xl170", "xl170 (Intel Xeon E5-2640v4 10 cores@2.4Ghz, Mellanox CX4 25GbE)"),
          ("c8220", "c8220 (2 x Intel Xeon E5-2660v2 10 cores@2.2Ghz, Qlogic 40Gbps)"),
          ("c6320", "c6320 (2 x Intel Xeon E5-2683v3 14 cores@2.0Ghz, Qlogic 40Gbps)"),
          ("c6220", "c6220 (2 x Intel Xeon E5-2650v2 8 cores@2.6Ghz, Mellanox CX3 56Gbps)"),
          ("r320", "r320 (Intel Xeon E5-2450 8 cores@2.1Ghz, Mellanox CX3 56Gbps)")]

num_nodes = range(2, 200)

pc.defineParameter("image", "Disk Image",
                   portal.ParameterType.IMAGE, images[0], images)

pc.defineParameter("type", "Node Type",
                   portal.ParameterType.NODETYPE, types[0], types)

pc.defineParameter("num_nodes", "# Nodes",
                   portal.ParameterType.INTEGER, 2, num_nodes)

pc.defineParameter("mlnx_dpdk_support", "Enable Mellanox OFED DPDK support?",
                   portal.ParameterType.BOOLEAN, False, [True, False])

params = pc.bindParameters()

rspec = RSpec.Request()

lan = RSpec.LAN()
rspec.addResource(lan)

node_names = ["rcnfs"]
for i in range(1, params.num_nodes):
    node_names.append("rc%02d" % i)

for name in node_names:
    node = RSpec.RawPC(name)

    if name == "rcnfs":
        # Ask for a 200GB file system mounted at /shome on rcnfs
        bs = node.Blockstore("bs", "/shome")
        bs.size = "200GB"

    node.hardware_type = params.type
    node.disk_image = 'urn:publicid:IDN+emulab.net+image+emulab-ops:' + params.image

    cmd_string = "sudo /local/repository/startup.sh"
    if params.mlnx_dpdk_support:
        cmd_string += " --mlnx-dpdk"
    node.addService(RSpec.Execute(shell="sh", command=cmd_string))

    rspec.addResource(node)

    iface = node.addInterface("eth0")
    lan.addInterface(iface)

pc.printRequestRSpec(rspec)

