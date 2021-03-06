# VMware ESXi Release Tagging

This PowerShell module tag ESXi servers in a vCenter with a human-readable release name, e.g. ESXi_7.0_Update_1c.
There is also a [blog post](https://www.why-did-it.fail/blog/2021-02-set-esxi-release-names-with-tags/) with a some of screenshots.

## Usage

0. Open Powershell

1. Clone the repository  
```powershell
# git clone https://github.com/dominikzorgnotti/VMware-ESXi-Release-Tagging.git
```
2. Move into the cloned directory
```powershell
# cd VMware-ESXi-Release-Tagging
```
4. Import the module from the current working directory
```powershell
# Import-Module .\VMware-ESXi-Release-Tagging.psd1
```
5. Make sure you are connected to a vCenter.  
Permissions must be sufficient to add tags and a tag category at global level and set tags to all ESXi hosts.
```powershell
# connect-viserver $vcenter
```
6. Execute the script 
```powershell
# Set-ESXiTagbyRelease
```

### Parameters
As of v0.1.0 the module will try to download the release information automatically from GitHub. If you're using a proxy PowerShell v6 and newer should be able to access your system settings for that.  
If you do not have Internet access, you can specify a custom URL or file path containing the required release information to the module. The required file with release information for ESXi can be found [here](https://raw.githubusercontent.com/dominikzorgnotti/vmware_product_releases_machine-readable/main/index/kb2143832_vmware_vsphere_esxi_table0_release_as-index.json).

Step 6 with custom local file location:
```powershell
# Set-ESXiTagbyRelease -ESXibuildsJSONFile "c:\temp\kb2143832_vmware_vsphere_esxi_table0_release_as-index.json"
```
Step 6 with custom URL:
```powershell
# Set-ESXiTagbyRelease -ESXibuildsJSONFile "https://192.168.10.2/path/kb2143832_vmware_vsphere_esxi_table0_release_as-index.json"
```


## Testing
I have tested the module against:

- Client operating system:
  - Microsoft Windows: 10.0.17763
- vSphere:
  - vCenter Server:
    -  7.0: Update 1d
  - ESXi hosts:
    - 7.0: Update 1c, Update 1d
- PowerShell: 
  - Core: v7.1.1, v7.1.2
- PowerCli modules: 12.2

## Acknowledgements

Thanks to [Michael](https://github.com/mdhemmi) for being the guinea pig :-)  
Thanks for my fellow TAMs for testing this with various operating systems and vSphere builds!