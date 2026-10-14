import geni.portal as portal
import geni.rspec.pg as rspec

NODE_TYPES = [
    ("c6525-100g", "c6525-100g (required baseline)"),
    ("r650", "r650"),
    ("r6525", "r6525"),
    ("d8545", "d8545"),
    ("c6620", "c6620"),
    ("d760", "d760"),
    ("r6615", "r6615"),
    ("d7615", "d7615"),
]

OS_IMAGES = [
    ("urn:publicid:IDN+emulab.net+image+emulab-ops//UBUNTU20-64-STD", "Ubuntu 20.04"),
]


def main():
    context = portal.Context()
    context.defineParameter(
        "nodeType",
        "Node type",
        portal.ParameterType.STRING,
        NODE_TYPES[0][0],
        NODE_TYPES,
        "",
    )

    context.defineParameter(
        "osImage",
        "Disk image",
        portal.ParameterType.STRING,
        OS_IMAGES[0][0],
        OS_IMAGES,
        "",
    )

    params = context.bindParameters()
    request = context.makeRequestRSpec()

    node = request.RawPC("node")
    node.hardware_type = params.nodeType
    node.disk_image = params.osImage

    # The artifact supports its cloudlab setup only on c6525-100g.
    ae_profile = "cloudlab" if params.nodeType == "c6525-100g" else "other"
    node.addService(
        rspec.Execute(shell="bash", command=f"/local/repository/setup.sh {ae_profile}")
    )

    context.printRequestRSpec(request)


if __name__ == "__main__":
    main()
