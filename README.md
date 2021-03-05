# VMware ESXi Release Tagging

I have created a PowerShell module that will take a JSON file as an input and tag ESXi servers with a human-readable release name.
This project continuous the work I have done on my projects to provide automation friendly VMware product release data:

-
-

## Usage




1. Clone the repository  
```powershell
# git clone https://github.com/dominikzorgnotti/VMware-ESXi-Release-Tagging.git
```
2. Move into the directory
```powershell
# cd VMware-ESXi-Release-Tagging
```
3. Get the JSON file with the ESXi release builds:
```text
Use curl, wget, browser, ... to get https://github.com/dominikzorgnotti/vmware_product_releases_machine-readable/blob/main/index/kb2143832_vmware_vsphere_esxi_table0_release_as-index.json
```
4. Load PowerCLI  
```powershell
# Import-Module VMware.PowerCLI
```
5. Import the module
```powershell
# Import-Module VMware-ESXi-Release-Tagging.psd1
```
6. Make sure you are connected to a vCenter
```powershell
# connect-viserver $vcenter
```
7. Execute the script
```powershell
# Set-ESXi-tag-by-release -ESXibuildsJSONFile kb2143832_vmware_vsphere_esxi_table0_release_as-index.json
```

## Testing
I have tested the module against:

- Windows 10
- vSphere 7
  - vCenter: vCenter Server Update 1d
  - ESXi hosts: ESX 7.0 Update 1c and Update 1d
- PowerShell: 
  - Core: v7.1.2
- PowerCli modules: 12.2
