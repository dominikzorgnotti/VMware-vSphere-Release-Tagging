#New-ModuleManifest -Path VMware-vSphere-Release-Tagging.psd1 -Author 'Dominik Zorgnotti' -RootModule VMware-vSphere-Release-Tagging.psm1 -Description 'Tag vSphere infrastructure with canonical release names' -CompanyName "Why did it Fail?" -RequiredModules @("VMware.VimAutomation.Core", "VMware.VimAutomation.Common") -FunctionsToExport @("Set-EsxiTagByRelease", "Import-BuildInformationFromJson") -PowerShellVersion '7.0' -ModuleVersion "1.0.0"


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
    __version__ = "1.0.0"
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

    # default assignments
    # The default download URL for the JSON data with ESXi release information
    $DEFAULT_ESXI_RELEASE_JSON = "https://raw.githubusercontent.com/dominikzorgnotti/vmware_product_releases_machine-readable/main/index/kb2143832_vmware_vsphere_esxi_table0_release_as-index.json"
    # Future addon-on? The valid entity types that can be given to get-vmhost as an argument for the -Location parameter
    # $VALID_ENTITY_TYPES = @("VMHost", "Datacenter", "Cluster", "Folder")
    
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
    Write-Host "Phase 1: Preparing pre-requisites" -ForegroundColor Magenta
    Write-Host ""

    # Converting JSON to Powershell object
    Write-Host "Reading ESXi release info..."
    # Check if were given an explicit parameter(https://stackoverflow.com/questions/48643250/how-to-check-if-a-powershell-optional-argument-was-set-by-caller), if not try to download from default location
    if (-not ($PSBoundParameters.ContainsKey('EsxiBuildsJsonFile'))) {
        $EsxiBuildsJsonFile = $DEFAULT_ESXI_RELEASE_JSON
    }
    $EsxiReleaseTable = Import-BuildInformationFromJson -ReleaseJsonLocation $EsxiBuildsJsonFile

    
    # By default, all hosts that are not disconnected will be targeted
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
    
    # When the list is empty nothing can be done    
    if ($VmHostList.count -le 0) {
        Write-Error -Message "The list of hosts is empty" -ErrorAction Stop
    }

    # Create a unique set of builds
    Write-Host "Building list of unique ESXi builds from the previous output"
    $UniqueBuilds = $VmHostList.build | Get-Unique

    # Getting tag categories ready to contain tags 
    Write-Host "Creating required tag category with name $EsxiReleaseCategoryName"
    if (Get-TagCategory -name $EsxiReleaseCategoryName -ErrorAction SilentlyContinue) {
        Write-Host "Noting to do. The category $EsxiReleaseCategoryName already exists" -ForegroundColor Gray
    }
    else {
        New-TagCategory -name $EsxiReleaseCategoryName -Cardinality "Single" -description "The category holds the ESXi release name tags" -EntityType "VMHost"
    }
    
    # Create a Null tag
    Write-Host "Creating a Null tag in case the build number cannot be found"
    $NullTagName = "no_matching_release"
    if (-not (Get-Tag -Name $NullTagName -Category $EsxiReleaseCategoryName -ErrorAction SilentlyContinue)) {
        New-Tag -name $NullTagName -Category $EsxiReleaseCategoryName -Description "No matching release found for the build number"
    }
   
    # Build a tag for each unique build
    Write-Host "Trying to create the required tags for each of the identified builds"

    $MappingTable = @{}

    foreach ($EsxiBuild in $UniqueBuilds) {
        Write-Host "Working on tags for ESXi build $EsxiBuild ..."
        
        if ($EsxiBuild -in $EsxiReleaseTable.PSobject.Properties.Name) {
            # Identify the release name based on the build provided as input
            $RequestedReleaseName = $EsxiReleaseTable.($EsxiBuild)."Version"
                          
            # Avoid escaping issues by replacing spaces with underscores
            $RequestedReleaseNameFormatted = $RequestedReleaseName.Replace(" ", "_")

            # Put the build and key tag name into the table
            [string]$EsxiBuildString = $EsxiBuild
            $MappingTable.add($EsxiBuildString, $RequestedReleaseNameFormatted)

        }
        else {
            write-host "Cannot find a name for the provided build $EsxiBuild." -ForegroundColor Red
            $RequestedReleaseNameFormatted = $false
        }
        
        # If the build is found in our table, create a tag
        if ($RequestedReleaseNameFormatted) {

            if (Get-Tag -name $RequestedReleaseNameFormatted -Category $EsxiReleaseCategoryName -ErrorAction SilentlyContinue) {
                Write-host "Nothing to do. Tag $RequestedReleaseNameFormatted already exists"
            }
            else {
                write-host "Creating tag $RequestedReleaseNameFormatted"
                New-Tag -name $RequestedReleaseNameFormatted -Category $EsxiReleaseCategoryName -Description ($EsxiReleaseTable.($EsxiBuild)."Version" + " (" + $EsxiReleaseTable.($EsxiBuild)."Release Name" + ") " + "- build: " + $EsxiBuild)
            }
            


        }
    }
    
    # Some nicer output to determine where we are
    Write-Host ""
    Write-Host "Phase 2: Apply information to ESXi hosts" -ForegroundColor Magenta
    Write-Host ""
    

    foreach ($VmHost in $VmHostList) {
        
        # Check if a tag is already assigned to a host and just remove it
        if (Get-TagAssignment -Category $EsxiReleaseCategoryName -Entity $VmHost -ErrorAction SilentlyContinue) {
            $CurrentHostTag = Get-TagAssignment -Category $EsxiReleaseCategoryName -Entity $VmHost
            Write-Host "Remove old tag from host $VmHost" -ForegroundColor Yellow
            Remove-TagAssignment -TagAssignment $CurrentHostTag -Confirm:$false
        }

        # Test if we can resolve the build, otherwise we cannot tag the host!
        [string]$CurrentEsxiBuild = $VmHost.build
        if ( $MappingTable.ContainsKey($CurrentEsxiBuild)) {
            # Lookup the build in the hashtable
            $TagLabel = $MappingTable.$CurrentEsxiBuild
            # Get the tag we need for the current host
            $EsxiReleaseTag = get-tag -name $TagLabel -Category $EsxiReleaseCategoryName

            # Assigning a matching tag
            Write-Host "Assign tag $EsxiReleaseTag to host $VmHost" -ForegroundColor Green
            New-TagAssignment -Tag $EsxiReleaseTag -Entity $VmHost 
        }
        else {
            # Adding NaN Tag to a host if we cannot look it up
            $EsxiNullTag = get-tag -Name $NullTagName -Category $EsxiReleaseCategoryName
            Write-Host "Build $CurrentEsxiBuild of host $VmHost cannot be identified " -ForegroundColor Yellow
            New-TagAssignment -tag $EsxiNullTag -Entity $VmHost
        }
    }
    

}


