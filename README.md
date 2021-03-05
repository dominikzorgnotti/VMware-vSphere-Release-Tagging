# VMware ESXi Release Tagging

This PowerShell module will take a JSON file as an input and tag ESXi servers in a vCenter with a human-readable release name.

## Usage

1. Clone the repository  
```powershell
# git clone https://github.com/dominikzorgnotti/VMware-ESXi-Release-Tagging.git
```
2. Move into the cloned directory
```powershell
# cd VMware-ESXi-Release-Tagging
```
3. Get the JSON file with the ESXi release builds:
```text
Use curl, wget, browser, ... to get https://raw.githubusercontent.com/dominikzorgnotti/vmware_product_releases_machine-readable/main/index/kb2143832_vmware_vsphere_esxi_table0_release_as-index.json
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
6. Execute the script but be sure to specify the right path to the JSON file. In my case it resides im my current working directory.
```powershell
# Set-ESXiTagbyRelease -ESXibuildsJSONFile .\kb2143832_vmware_vsphere_esxi_table0_release_as-index.json
```

## Testing
I have tested the module against:

- Client operating system:
  - Microsoft Windows: 10.0.17763
- vSphere 7
  - vCenter Server:
    -  7.0: Update 1d
  - ESXi hosts:
    - 7.0: Update 1c, Update 1d
- PowerShell: 
  - Core: v7.1.2
- PowerCli modules: 12.2

## Acknowledgements

Thanks to [Michael](https://github.com/mdhemmi) for being the guinea pig :-)
