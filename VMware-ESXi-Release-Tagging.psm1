#New-ModuleManifest -Path VMware-ESXi-Release-Tagging.psd1 -Author 'Dominik Zorgnotti' -RootModule VMware-ESXi-Release-Tagging.psm1 -Description 'Tag ESXi with canonical release names' -CompanyName "Why did it Fail?" -RequiredModules "VMware.VimAutomation.Core, VMware.VimAutomation.Common" -FunctionsToExport "Set-ESXi-tag-by-release" -PowerShellVersion '6.0'


Function Get-ESXi-builds-from-file {
    <#
        .NOTES
            (c) 2021 Dominik Zorgnotti (dominik@why-did-it.fail)
        .DESCRIPTION
            Reads ESXi build information from a JSON file 
        .PARAMETER ESXibuildsJSON
            A json file containing ESXi build information, it is expected that the JSON key is equal to the build number.
            You can fine such a file here: https://github.com/dominikzorgnotti/vmware_product_releases_machine-readable/blob/main/index/kb2143832_vmware_vsphere_esxi_table0_release_as-index.json

            # TODO, will try to load this directly from the internet
        #>
    param(
        [Parameter(Mandatory = $true)][string]$ESXibuildsJSON
    )
    Try {
        $ESXiReleaseTable = Get-Content -Raw -Path $ESXibuildsJSON | ConvertFrom-Json
    }
    catch [System.IO.FileNotFoundException] {
        Write-Error -Message "Could not find $ESXibuildsJSON" -ErrorAction Stop
    }
    return $ESXiReleaseTable
}
    

Function New-ESXi-tag-by-release {
    <#
        .NOTES
            (c) 2021 Dominik Zorgnotti (dominik@why-did-it.fail)
        .DESCRIPTION
            Use this function to add a tag to ESXi hosts that will contain the release (canonical) name, e.g. ESXi_7.0_Update_1c
            Returns a hashtable that contains a mapping between builds and tag names
        .PARAMETER ESXiBuild
            The build number of an ESXi host as provided by the build properity from vm-host 
        .PARAMETER ESXiReleaseTable
            An object with converted JSON data as provided the function Get-ESXi-builds-from-file
        .PARAMETER ESXiReleaseCategoryName
            The category in which the tags will be created as specified in the function new-esx-release-tag-category
    #>
    param(
        [Parameter(Mandatory = $true)]$ESXiBuildList,
        [Parameter(Mandatory = $true)]$ESXiReleaseTable,
        [Parameter(Mandatory = $true)]$ESXiReleaseCategoryName
    )

    # Relate buildnumber to tag name
    $mapping_table = @{}
    
    # Build a tag for each unique build
    foreach ($ESXiBuild in $ESXiBuildList) {
        Write-Host "Working on tags for ESXi build $ESXiBuild ..."
        # Check if we have that build in our list
        if ($ESXiBuild -in $ESXiReleaseTable.PSobject.Properties.Name) {
            # Identify the release name based on the build provided as input
            $requested_release_name = $ESXiReleaseTable.($ESXiBuild)."Release Name"
                          
            # Avoid escaping issues by replacing spaces with underscores
            $requested_release_name_fmt = $requested_release_name.Replace(" ", "_")

            # Add a mapping between build and future tag
            $mapping_table.Add($ESXiBuild, $requested_release_name_fmt)

            # Identify if a release tag for this build already exists
            if (Get-Tag -name $requested_release_name_fmt -ErrorAction SilentlyContinue) {
                Write-host "Nothing to do. Tag $requested_release_name_fmt already exists"
            }
            else {
                write-host "Creating tag $requested_release_name_fmt"
                New-Tag -name $requested_release_name_fmt -Category $ESXiReleaseCategoryName -Description ($ESXiReleaseTable.($ESXiBuild)."Release Name" + " - build: " + $ESXiBuild)
            }
    
        }
        else {
            write-host "Cannot create a tag for the provided build number."
        }
        # Create a NaN tag
        if (Get-Tag -Name "no_matching_release" -ErrorAction SilentlyContinue) {
            New-Tag -name "no_matching_release" -Category $ESXiReleaseCategoryName -Description "No matching release found for the build number"
        }
    }
    return $mapping_table
}


Function Set-ESXi-tag-by-release {
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

    # Converting JSON file to Powershell object
    Write-Host "Reading release info from $ESXibuildsJSONFile"
    $ESXiReleaseTable = Get-ESXi-builds-from-file -ESXibuildsJSON $ESXibuildsJSONFile

    # Getting tag categories ready to contain tags 
    Write-Host "Creating required tag category with name $ESXiReleaseCategoryName"
    if (Get-TagCategory -name $ESXiReleaseCategoryName -ErrorAction SilentlyContinue) {
        Write-Host "Noting to do. The category $ESXiReleaseCategoryName already exists"
    }
    else {
        New-TagCategory -name $ESXiReleaseCategoryName -Cardinality "Single" -description "The category holds the ESXi release name tags" -EntityType "VMHost"
    }
    
    # Until I can fix it, all hosts that will are not disconnected will be targeted
    Write-Host "Building list of all ESXi hosts..."
    $vmhost_list = get-vmhost | Where-Object { $_.ConnectionState -ne 'disconnected' }
    
    # Create a unique set of builds
    Write-Host "Building list of unique ESXi builds from the previous output"
    $unique_builds = $vmhost_list.build | Get-Unique
   
    # Holds a smaller mapping hash table between ESXi builds and actual tag names
    Write-Host "Trying to create the required tags for each of the identified builds"
    $hashtable_builds_tags = New-ESXi-tag-by-release -ESXiBuildList $unique_builds -ESXiReleaseCategoryName $ESXiReleaseCategoryName -ESXiReleaseTable $ESXiReleaseTable
   
    foreach ($vmhost in $vmhost_list) {
        
        # Check if a tag is already assigned to a host and just remove it
        if (Get-TagAssignment -Category $ESXiReleaseCategoryName -Entity $vmhost -ErrorAction SilentlyContinue) {
            $current_host_tag = Get-TagAssignment -Category $ESXiReleaseCategoryName -Entity $vmhost
            Remove-TagAssignment -TagAssignment $current_host_tag -WhatIf:$true
        }

        # Test if we have that the tag in the hash table, otherwise we cannot tag the host!
        $current_build = $vmhost.build
        if ($hashtable_builds_tags.ContainsKey($current_build)) {
            # Lookup the build in the hasbtable
            $tag_label = $hashtable_builds_tags.get_item($vmhost.build)
            # Get the tag we need for the current host
            $release_tag = get-tag -name $tag_label

            # Assigning a matching tag
            Write-Host "Assign tag $release_tag to host"
            New-TagAssignment -Tag $release_tag -Entity $vmhost 
        }
        else {
            # Adding NaN Tag to a host if we cannot look it up
            $nan_tag = get-tag -Name "no_matching_release"
            New-TagAssignment -tag $nan_tag -Entity $vmhost
        }
    }
    

}
