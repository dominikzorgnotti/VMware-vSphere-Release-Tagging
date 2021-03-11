#New-ModuleManifest -Path VMware-vSphere-Release-Tagging.psd1 -Author 'Dominik Zorgnotti' -RootModule VMware-vSphere-Release-Tagging.psm1 -Description 'Tag vSphere infrastructure with canonical release names' -CompanyName "Why did it Fail?" -RequiredModules @("VMware.VimAutomation.Core", "VMware.VimAutomation.Common") -FunctionsToExport @("Set-EsxiTagByRelease", "Import-BuildInformationFromJson") -PowerShellVersion '7.0' -ModuleVersion "1.1.1"


Function Import-BuildInformationFromJson {
    <#
.SYNOPSIS
  Imports a file, either a local or as URL, and returns the output converted to JSON
.DESCRIPTION
  Imports a file, either a local or as URL, and returns the output converted to JSON
.PARAMETER ReleaseJsonLocation
A json file containing vSphere (VC, ESXi) build information, it is expected that the JSON key is equal to the build number.
.NOTES
  __author__ = "Dominik Zorgnotti"
  __contact__ = "dominik@why-did-it.fail"
  __created__ = "2021-03-06"
  __deprecated__ = False
  __contact__ = "dominik@why-did-it.fail"
  __license__ = "GPLv3"
  __status__ = "released"
  __version__ = "1.0.0"
.EXAMPLE
Import-BuildInformationFromJson -ReleaseJsonLocation "c:\temp\kb2143832_vmware_vsphere_esxi_table0_release_as-index.json"
.EXAMPLE
Import-BuildInformationFromJson -ReleaseJsonLocation "https://raw.githubusercontent.com/dominikzorgnotti/vmware_product_releases_machine-readable/main/index/kb2143832_vmware_vsphere_esxi_table0_release_as-index.json"
#>
    param(
        [Parameter(Mandatory = $true)][string]$ReleaseJsonLocation
    )
    # Test if it is a local file
    if ((Get-Item $ReleaseJsonLocation -ErrorAction SilentlyContinue) -is [System.IO.fileinfo]) {
        try {
            Write-Host "Trying to access local file $ReleaseJsonLocation"
            $FileContent = Get-Content -Raw -Path $ReleaseJsonLocation | ConvertFrom-Json 
        }
        catch {
            Write-Error "Cannot fetch required JSON data from local path." -ErrorAction Stop
        }
    }
    # else: it must be a url
    else {
        try {
            # Not pretty, but I added SkipCertificateCheck to handle 99% of all custom URL handling issues
            Write-Host "Trying web location at $ReleaseJsonLocation..."
            $FileContent = (Invoke-WebRequest -SkipCertificateCheck -Uri $ReleaseJsonLocation).content | ConvertFrom-Json
        }
        catch {
            $StatusCode = $_.Exception.Response.StatusCode.value__
            Write-Error "Cannot download required JSON data from your location. Status is $StatusCode" -ErrorAction Stop
        }
    }
    return $FileContent
}


Function Set-EsxiTagByRelease {
    <#
.SYNOPSIS
  Assigns a tag containing the vSphere release name to ESXi hosts.
.DESCRIPTION
  Assigns a tag containing the vSphere release name to all ESXi hosts.
.PARAMETER EsxiBuildsJson
  [optional] A path (URL or local) to a json file containing ESXi build information, it is expected that the JSON key is equal to the build number.
  You can fine such a file here: https://github.com/dominikzorgnotti/vmware_product_releases_machine-readable/blob/main/index/kb2143832_vmware_vsphere_esxi_table0_release_as-index.json
.PARAMETER EsxiReleaseCategoryName
  [optional] The name of the vCenter tag category, defaults to tc_esxi_release_names
.PARAMETER Entity
  [optional] A VI object of the types (VMhost | Cluster | Datacenter | Folder) that sets the scope of the tagging. Default will be all VMhosts in a vCenter.
.NOTES
    __author__ = "Dominik Zorgnotti"
    __contact__ = "dominik@why-did-it.fail"
    __created__ = "2021-03-04"
    __deprecated__ = False
    __contact__ = "dominik@why-did-it.fail"
    __license__ = "GPLv3"
    __status__ = "released"
    __version__ = "1.1.1"
.EXAMPLE
  Set-EsxiTagByRelease
.EXAMPLE
  Set-EsxiTagByRelease -Entity (get-cluster "production")
.EXAMPLE
  Set-EsxiTagByRelease -EsxiBuildsJsonFile "c:\temp\kb2143832_vmware_vsphere_esxi_table0_release_as-index.json"
.EXAMPLE
  Set-EsxiTagByRelease -EsxiBuildsJsonFile "https://192.168.10.2/path/kb2143832_vmware_vsphere_esxi_table0_release_as-index.json" -EsxiReleaseCategoryName "Release_Info"
.EXAMPLE
  Set-EsxiTagByRelease -EsxiReleaseCategoryName "Release_Info"
.EXAMPLE
  Set-EsxiTagByRelease -Entity (get-vmhost "esx1.corp.local")
#>

    # Do not over-engineer: Entity will just do a basic sanity check if a valid VIobject is returned.
    # Input by pipeline is a bit tricky, skipping for now.
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $false)]
        [string]$EsxiReleaseCategoryName = "tc_esxi_release_names"
        ,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false)]
        [string]$EsxiBuildsJsonFile
        ,
        [ValidateScript( { ( Get-inventory ($_)) })]
        [Parameter(Mandatory = $false, ValueFromPipeline = $false)]
        $Entity
    )
    begin {
        # Some nicer output to determine where we are
        Write-Host ""
        Write-Host "Phase 1: Preparing pre-requisites" -ForegroundColor Magenta
        Write-Host ""

        # Check if we are connected to a vCenter
        if ($global:DefaultVIServers.count -eq 0) {
            Write-Error -Message "Please make sure you are connected to a vCenter." -ErrorAction Stop
        }

        # Compatibility for hosts with Hyper-V modules
        if (get-module -name Hyper-V -ErrorAction SilentlyContinue) {
            Remove-Module -Name Hyper-V -confirm:$false
        }

    }
    process {
        # default assignments
        # The default download URL for the JSON data with ESXi release information
        $DEFAULT_ESXI_RELEASE_JSON = "https://raw.githubusercontent.com/dominikzorgnotti/vmware_product_releases_machine-readable/main/index/kb2143832_vmware_vsphere_esxi_table0_release_as-index.json"
        # Future addon-on? The valid entity types that can be given to get-vmhost as an argument for the -Location parameter
        # $VALID_ENTITY_TYPES = @("VMHost", "Datacenter", "Cluster", "Folder")
    

        # Converting JSON to Powershell object
        Write-Host "Importing ESXi release info..."
        # Check if were given an explicit parameter(https://stackoverflow.com/questions/48643250/how-to-check-if-a-powershell-optional-argument-was-set-by-caller), if not try to download from default location
        if (-not ($PSBoundParameters.ContainsKey('EsxiBuildsJsonFile'))) {
            $EsxiBuildsJsonFile = $DEFAULT_ESXI_RELEASE_JSON
        }
        $EsxiReleaseTable = Import-BuildInformationFromJson -ReleaseJsonLocation $EsxiBuildsJsonFile
          
        # Backstop: When the list of releases is empty nothing can be done    
        if (-not $EsxiReleaseTable) {
            Write-Error -Message "The list of ESXi releases is empty" -ErrorAction Stop
        }


        # By default, all hosts in a vCenter that are not disconnected will be targeted
        if (-not ($PSBoundParameters.ContainsKey('Entity'))) {
            Write-Host "Building list of all ESXi hosts..."
            $VmHostList = get-vmhost | Where-Object { $_.ConnectionState -ne 'disconnected' }
        }
        else {
            Write-Host "Building list of ESXi hosts in this scope..."
            # Test if a VMhost object was already passed on
            if ($Entity[0] -is [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]) {
                $VmHostList = $Entity | Where-Object { $_.ConnectionState -ne 'disconnected' }
            }
            else {
                $VmHostList = get-vmhost -Location $Entity | Where-Object { $_.ConnectionState -ne 'disconnected' }
            }
        }
    
        # Backstop: When the list of hosts is empty nothing can be done    
        if ($VmHostList.count -le 0) {
            Write-Error -Message "The list of hosts is empty" -ErrorAction Stop
        }

        # Getting tag category ready to contain the ESXi release tags 
        if (-not (Get-TagCategory -name $EsxiReleaseCategoryName -ErrorAction SilentlyContinue)) {
            Write-Host "Creating required tag category with name $EsxiReleaseCategoryName"
            New-TagCategory -name $EsxiReleaseCategoryName -Cardinality "Single" -description "The category holds the ESXi release name tags" -EntityType "VMHost"
        }
     
        # Create a Null tag in case the release cannot be found
        Write-Host "Creating a Null tag in case the build number cannot be found"
        $NullTagName = "no_matching_release"
        if (-not (Get-Tag -Name $NullTagName -Category $EsxiReleaseCategoryName -ErrorAction SilentlyContinue)) {
            New-Tag -name $NullTagName -Category $EsxiReleaseCategoryName -Description "No matching release found for the build number"
        }
        $NullTag = Get-Tag -Name $NullTagName -Category $EsxiReleaseCategoryName
        
        # Create a unique set of builds from the list of hosts to avoid duplicate work
        Write-Host "Building list of unique ESXi builds from the previous output"
        $UniqueBuilds = $VmHostList.build | Get-Unique

        Write-Host ""
        Write-Host "Phase 2: Building tags and applying information to the ESXi hosts" -ForegroundColor Magenta
        Write-Host ""

        # for each build in builds, build a tag and assign to current_tag. if not found, assign null tag to current_tag
        # filter hosts by build, assign current tag

        foreach ($EsxiBuild in $UniqueBuilds) {
            Write-Host "Working on tags for ESXi build $EsxiBuild ..."

            # If we have the build in the JSON file, then build and assign the matching tag to the $DesignatedHostTag variable
            if ($EsxiBuild -in $EsxiReleaseTable.PSobject.Properties.Name) {
                
                # Identify the release version based on the build provided as input
                $RequestedReleaseVersion = $EsxiReleaseTable.($EsxiBuild)."Version"          
                # Avoid escaping issues by replacing spaces with underscores
                $RequestedReleaseVersionFormatted = $RequestedReleaseVersion.Replace(" ", "_")
                # Release Name
                $RequestedReleaseName = $EsxiReleaseTable.($EsxiBuild)."Release Name"

                # Check if a matching tag already exists in the vCenter
                if (-not (Get-Tag -name $RequestedReleaseVersionFormatted -Category $EsxiReleaseCategoryName -ErrorAction SilentlyContinue)) {
                    # Create the tag if it does not exist
                    write-host "Creating tag $RequestedReleaseVersionFormatted"
                    New-Tag -name $RequestedReleaseVersionFormatted -Category $EsxiReleaseCategoryName -Description ($RequestedReleaseVersion + " (" + $RequestedReleaseName + ") " + "- build: " + $EsxiBuild)
                }
                # Now that the tag is available, assign it to the $DesignatedHostTag variable for further processing. Backstop: If the tag is empty, stop here!
                $DesignatedHostTag = Get-Tag -name $RequestedReleaseVersionFormatted -Category $EsxiReleaseCategoryName -ErrorAction Stop
            }
            else {
                # handle the case where the build has not been found by assigning a Null-tag to the $DesignatedHostTag 
                write-host "Cannot find a name for the provided build $EsxiBuild!" -ForegroundColor Red
                $DesignatedHostTag = $NullTag
            }

            # Now, loop through all ESXi hosts with the $EsxiBuild and assign the $DesignatedHostTag 
            foreach ($VmHost in ($VmHostList | Where-Object { $_.Build -eq $EsxiBuild })) {
        
                # Check if a release tag is already assigned to a host and remove it makes no sense to have two release tags on the same host
                if (Get-TagAssignment -Category $EsxiReleaseCategoryName -Entity $VmHost -ErrorAction SilentlyContinue) {
                    $CurrentReleaseTag = Get-TagAssignment -Category $EsxiReleaseCategoryName -Entity $VmHost
                    Write-Host "Removing old release tag from host $VmHost" -ForegroundColor Yellow
                    Remove-TagAssignment -TagAssignment $CurrentReleaseTag -Confirm:$false
                }      
                # Finally, assign the tag
                Write-Host "Assigning tag $DesignatedHostTag to host $VmHost" -ForegroundColor Green
                New-TagAssignment -Tag $DesignatedHostTag -Entity $VmHost
            }
        }
    }
}
                    


