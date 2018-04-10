import geni.portal as portal
import geni.rspec.pg as RSpec
import geni.urn as urn
import geni.aggregate.cloudlab as cloudlab

pc = portal.Context()

images = [ ("UBUNTU16-64-STD", "Ubuntu 16.04") ]

types = [ ("m510", "m510 (Intel Xeon-D)"),
          ("d430", "d430 (Intel 2x10GbE)"),
          ("xl170", "xl170 (Intel Xeon-E5 2x25GbE)")]

num_nodes = range(2, 45)

pc.defineParameter("image", "Disk Image",
                   portal.ParameterType.IMAGE, images[0], images)

pc.defineParameter("type", "Node Type",
                   portal.ParameterType.NODETYPE, types[0], types)

pc.defineParameter("num_nodes", "# Nodes",
                   portal.ParameterType.INTEGER, 2, num_nodes)

params = pc.bindParameters()
#pc.verifyParameters()

rspec = RSpec.Request()

lan = RSpec.LAN()
rspec.addResource(lan)

node_names = ["rcmaster", "rcnfs"]
for i in range(params.num_nodes - 2):
    node_names.append("rc%02d" % (i + 1))

for name in node_names:
    node = RSpec.RawPC(name)

    if name == "rcnfs":
        # Ask for a 200GB file system mounted at /shome on rcnfs
        bs = node.Blockstore("bs", "/shome")
        bs.size = "200GB"

    node.hardware_type = params.type
    node.disk_image = urn.Image(cloudlab.Utah,"emulab-ops:%s" % params.image)
#    node.component_id = urn.Node(cloudlab.Utah, name)

    node.addService(RSpec.Execute(
            shell="sh",
            command="sudo /local/repository/startup.sh &>> /local/startup.log"))

    rspec.addResource(node)

    iface = node.addInterface("eth0")
    lan.addInterface(iface)

pc.printRequestRSpec(rspec)

