#New-ModuleManifest -Path VMware-ESXi-Release-Tagging.psd1 -Author 'Dominik Zorgnotti' -RootModule VMware-ESXi-Release-Tagging.psm1 -Description 'Tag ESXi with canonical release names' -CompanyName "Why did it Fail?" -RequiredModules @("VMware.VimAutomation.Core", "VMware.VimAutomation.Common") -FunctionsToExport @("Set-ESXiTagbyRelease") -PowerShellVersion '7.0' -ModuleVersion "0.0.2"
Function Set-ESXiTagbyRelease {
    <#
.SYNOPSIS
  Assigns a tag containing the vSphere release name to ESXi hosts.
.DESCRIPTION
  Assigns a tag containing the vSphere release name to all ESXi hosts.
  # BIG TODO: Provide entity or something to make this more targeted
  A JSON file providing the required build information must be provided, you can fine such a file here: https://github.com/dominikzorgnotti/vmware_product_releases_machine-readable/blob/main/index/kb2143832_vmware_vsphere_esxi_table0_release_as-index.json
.PARAMETER ESXibuildsJSON
  A json file containing ESXi build information, it is expected that the JSON key is equal to the build number.
  You can fine such a file here: https://github.com/dominikzorgnotti/vmware_product_releases_machine-readable/blob/main/index/kb2143832_vmware_vsphere_esxi_table0_release_as-index.json
.PARAMETER ESXiReleaseCategoryName
  [optional] The name of the vCenter tag category, defaults to tc_esxi_release_names
.NOTES
    __author__ = "Dominik Zorgnotti"
    __contact__ = "dominik@why-did-it.fail"
    __created__ = "2021-03-04"
    __deprecated__ = False
    __contact__ = "dominik@why-did-it.fail"
    __license__ = "GPLv3"
    __status__ = "beta"
    __version__ = "0.0.3"
.EXAMPLE
  tag-esxi-with-release-name -ESXibuildsJSON kb2143832_vmware_vsphere_esxi_table0_release_as-index.json
.EXAMPLE
  tag-esxi-with-release-name -ESXibuildsJSON kb2143832_vmware_vsphere_esxi_table0_release_as-index.json -ESXiReleaseCategoryName "Release_Info"
#>

    # TODO: How to target Entity (Folder, Datacenter, Cluster, Single VMhost) for a subset of hosts?
    param(
        [Parameter(Mandatory = $false)][string]$ESXiReleaseCategoryName = "tc_esxi_release_names",
        [Parameter(Mandatory = $true)][string]$ESXibuildsJSONFile
    )

    # Check if we are connected to a vCenter
    if ($global:DefaultVIServers.count -eq 0) {
        Write-Error -Message "Please make sure you are connected to a vCenter." -ErrorAction Stop
    }

    # Compatibility for hosts with Hyper-V modules
    if (get-module -name Hyper-V -ErrorAction SilentlyContinue) {
        Remove-Module -Name Hyper-V -confirm:$false
    }

    # Some nicer output to determine where we are
    Write-Host ""
    Write-Host "Phase 1: Preparing pre-requisists" -ForegroundColor Magenta
    Write-Host ""

    # Converting JSON file to Powershell object
    Write-Host "Reading release info from $ESXibuildsJSONFile"
    Try {
        $ESXiReleaseTable = Get-Content -Raw -Path $ESXibuildsJSONFile | ConvertFrom-Json
    }
    catch [System.IO.FileNotFoundException] {
        Write-Error -Message "Could not find $ESXibuildsJSON" -ErrorAction Stop
    }
  
    # Until I can fix it, all hosts that will are not disconnected will be targeted
    Write-Host "Building list of all ESXi hosts..."
    $vmhost_list = get-vmhost | Where-Object { $_.ConnectionState -ne 'disconnected' }
    
    # Create a unique set of builds
    Write-Host "Building list of unique ESXi builds from the previous output"
    $unique_builds = $vmhost_list.build | Get-Unique

    # Getting tag categories ready to contain tags 
    Write-Host "Creating required tag category with name $ESXiReleaseCategoryName"
    if (Get-TagCategory -name $ESXiReleaseCategoryName -ErrorAction SilentlyContinue) {
        Write-Host "Noting to do. The category $ESXiReleaseCategoryName already exists" -ForegroundColor Gray
    }
    else {
        New-TagCategory -name $ESXiReleaseCategoryName -Cardinality "Single" -description "The category holds the ESXi release name tags" -EntityType "VMHost"
    }
    
    # Create a Null tag
    Write-Host "Creating a Null tag in case the build number cannot be found"
    $null_tag_name = "no_matching_release"
    if (-not (Get-Tag -Name $null_tag_name -ErrorAction SilentlyContinue)) {
        New-Tag -name $null_tag_name -Category $ESXiReleaseCategoryName -Description "No matching release found for the build number"
    }
   
    # Build a tag for each unique build
    Write-Host "Trying to create the required tags for each of the identified builds"

    $mapping_table = @{}

    foreach ($ESXiBuild in $unique_builds) {
        Write-Host "Working on tags for ESXi build $ESXiBuild ..."
        
        if ($ESXiBuild -in $ESXiReleaseTable.PSobject.Properties.Name) {
            # Identify the release name based on the build provided as input
            $requested_release_name = $ESXiReleaseTable.($ESXiBuild)."Release Name".Replace(" ", "_")
                          
            # Avoid escaping issues by replacing spaces with underscores
            $requested_release_name_fmt = $requested_release_name.Replace(" ", "_")

            # Put the build and key tag name into the table
            [string]$build_as_string = $ESXiBuild
            $mapping_table.add($build_as_string, $requested_release_name_fmt)

        }
        else {
            write-host "Cannot find a name for the provided build $ESXiBuild." -ForegroundColor Red
            $requested_release_name_fmt = $false
        }
        
        # If the build is found in our table, create a tag
            if ($requested_release_name_fmt) {

            if (Get-Tag -name $requested_release_name_fmt -ErrorAction SilentlyContinue) {
                Write-host "Nothing to do. Tag $requested_release_name_fmt already exists"
            }
            else {
                write-host "Creating tag $requested_release_name_fmt"
                New-Tag -name $requested_release_name_fmt -Category $ESXiReleaseCategoryName -Description ($ESXiReleaseTable.($ESXiBuild)."Release Name" + " - build: " + $ESXiBuild)
            }
            


        }
        }
    
    # Some nicer output to determine where we are
    Write-Host ""
    Write-Host "Phase 2: Apply information to ESXi hosts" -ForegroundColor Magenta
    Write-Host ""
    

    foreach ($vmhost in $vmhost_list) {
        
        # Check if a tag is already assigned to a host and just remove it
        if (Get-TagAssignment -Category $ESXiReleaseCategoryName -Entity $vmhost -ErrorAction SilentlyContinue) {
            $current_host_tag = Get-TagAssignment -Category $ESXiReleaseCategoryName -Entity $vmhost
            Write-Host "Remove old tag from host $vmhost" -ForegroundColor Yellow
            Remove-TagAssignment -TagAssignment $current_host_tag -Confirm:$false
        }

        # Test if we can resolve the build, otherwise we cannot tag the host!
        [string]$current_build = $vmhost.build
        if ( $mapping_table.ContainsKey($current_build)) {
            # Lookup the build in the hasbtable
            $tag_label = $mapping_table.$current_build
            # Get the tag we need for the current host
            $release_tag = get-tag -name $tag_label

            # Assigning a matching tag
            Write-Host "Assign tag $release_tag to host $vmhost" -ForegroundColor Green
            New-TagAssignment -Tag $release_tag -Entity $vmhost 
        }
        else {
            # Adding NaN Tag to a host if we cannot look it up
            $null_tag = get-tag -Name $null_tag_name
            Write-Host "Build $current_build of host $vmhost cannot be identified " -ForegroundColor Yellow
            New-TagAssignment -tag $null_tag -Entity $vmhost
        }
    }
    

}
