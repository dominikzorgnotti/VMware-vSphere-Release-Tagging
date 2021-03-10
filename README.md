# VMware vSphere Release Tagging (formerly: VMware ESXi Release Tagging)

This PowerShell module uses vSphere tags to apply a human-readable release name, e.g. ESXi_7.0_Update_1c, to ESXi.
In the future vCenter this will be also extended to tag a vCenter object as well.  
There is a [blog post](https://www.why-did-it.fail/blog/2021-02-set-esxi-release-names-with-tags/) available with a some of screenshots.

## Release Notes

Since v1.0.0 the PowerShell module has been renamed to VMware vSphere Release Tagging.  
Find release information in the [release overview](https://github.com/dominikzorgnotti/VMware-vSphere-Release-Tagging/releases).

## Getting started

0. Open Powershell

1. Clone the repository

```powershell
# git clone https://github.com/dominikzorgnotti/VMware-vSphere-Release-Tagging.git
```

2. Move into the cloned directory

```powershell
# cd VMware-vSphere-Release-Tagging
```

3. Import the module from the current working directory

```powershell
# Import-Module .\VMware-vSphere-Release-Tagging.psd1
```

4. Make sure you are connected to a vCenter.  
   Permissions must be sufficient to add tags and a tag category at global level and set tags to all ESXi hosts.

```powershell
# connect-viserver $vcenter
```

## Tagging ESXi hosts

5. Execute the command without parameters to tag all your ESXi hosts in a vCenter

```powershell
# Set-EsxiTagByRelease
```

### Parameters

#### -EsxiReleaseCategoryName

The name of the tag category within vCenter that holds the created tags. It defaults to "tc_esxi_release_names".

#### -EsxiBuildsJsonFile

As of v0.1.0 the module will try to download the release information automatically from GitHub. If you're using a proxy PowerShell v6 and newer should be able to access your system settings for that.  
If you do not have Internet access, you can specify a custom URL or file path containing the required release information to the module. The required file with release information for ESXi can be found [here](https://raw.githubusercontent.com/dominikzorgnotti/vmware_product_releases_machine-readable/main/index/kb2143832_vmware_vsphere_esxi_table0_release_as-index.json).

Specify a custom local file location:

```powershell
# Set-EsxiTagByRelease -EsxiBuildsJsonFile "c:\temp\kb2143832_vmware_vsphere_esxi_table0_release_as-index.json"
```

Specify a custom URL:

```powershell
# Set-EsxiTagByRelease -EsxiBuildsJsonFile "https://192.168.10.2/path/kb2143832_vmware_vsphere_esxi_table0_release_as-index.json"
```

#### -Entity

v0.2.0 adds the optional ability to limit the tag application to a scope (i.e. not all hosts will be tagged).  
This is provided by the the parameter "-Entity" which expects a VI object (e.g. get-cluster "production) as an argument.
Currently, there is no support to pass on the VI object via pipeline ( | )

Apply the tags only to the ESXi hosts in the "production" cluster:

```powershell
#  Set-EsxiTagByRelease -Entity (get-cluster "production")
```

## Tagging vCenter hosts

Currently, a roadmap item, see [Issue #4](https://github.com/dominikzorgnotti/VMware-vSphere-Release-Tagging/issues/4)

## Testing

I have tested the module against:

- Client operating system:
  - Microsoft Windows: 10.0.17763
- vSphere:
  - vCenter Server:
    - 7.0: Update 1d
  - ESXi hosts:
    - 7.0: Update 1c, Update 1d
- PowerShell:
  - Core: v7.1.1, v7.1.2
- PowerCli modules: 12.2

## Acknowledgements

Thanks to [Michael](https://github.com/mdhemmi) for being the guinea pig :-)  
Thanks for my fellow TAMs for testing this with various operating systems and vSphere builds!
