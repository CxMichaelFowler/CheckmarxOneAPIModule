﻿#----------------------------------------------------------------------------------------------------------------------------------------------------
#region Help

<#
.Synopsis
    This module has been created to simplify common tasks when scritpting for Checkmarx One

.Notes   
    Version:     1.0
    Date:        20/01/2025
    Written by:  Michael Fowler
    Contact:     michael.fowler@checkmarx.com
    
    Change Log
    Version    Detail
    -----------------
    1.0        Original version
    
.Description
    The following functions are available for this module
    
    ApiCall
        Details
            Function to take an Invoke-WebRequest or Invoke-RestMethod script block
            Will recreate authorisation token if due to expire
            Performs error handling
        Parameters
            ScriptBlock - Script block to run. Must be Invoke-WebRequest or Invoke-RestMethod
            conn - a Checkmarx One connection object
            noerror - switch to ignore error hanlder and rethrow the error
        Examplle 
            $response = ApiCall { Invoke-WebRequest $uri -Method GET -Headers $conn.Headers } $conn
    
    New-Connection
        Details
            Function to create a Checkmarx Connection object with a prompt for the API Key
            Connection object is needed for additional calls in module
            Connection object contains the BaseURI and Authorisdation Headers
        Parameters
            No Parameters required
        Example 
            $conn = New-Connection
    
    New-SilentConnection
        Details
            Function to create a Checkmarx Connection object with a provided API Key
            Connection object is needed for additional calls in modeule
            Connection object contains the BaseURI and Authorisdation Headers
        Parameters
            apikey - Checkmarx One API key
        Example
            $conn = New-SilentConnection "<API_KEY>"
        
    Get-AllProjects
        Details
            Function to return a list of all projects
            Returns a List of project objects
        Parameters
            CxOneConnObj - Checkmarx One connection object
            getBranches - Optional switch to determine if project branches should be returned for the projects
        Example
            $projects = Get-AllProjects $conn
    
    Get-ProjectsByNames
        Details 
            Function to get a list of projects filtered by CSV string of project names
        Parameters
            CxOneConnObj - Checkmarx One connection object
            projectNames - CSV string of project names to filter results returned
            getBranches - Optional switch to determine if project branches should be returned for the projects
        Example
            $projects = Get-AllProjects $conn "project1,project2,project3"
                  
    Get-ProjectsByIds
        Details
            Function to get a list of projects filtered by CVS string of project ids
        Parameters
            CxOneConnObj - Checkmarx One connection object
            projectIds - CSV string of project Ids to filter results returned
            getBranches - Optional switch to determine if project branches should be returned for the projects
        Example
            $projects = Get-AllProjects $conn "<project_id_1>,<project_id_2>,<project_id_3>"
        
    Get-AllScans
        Details
            Function to get all scans filtered by statuses provided as a CSV string.
            Valid Statuses are Queued, Running, Completed, Failed, Partial, Canceled
            All Statuses are required pass $null or empty string for statuses
        Parameters
            CxOneConnObj - Checkmarx One connection object
            statuses - CSV string of scan statuses to filter results
        Example
            $scans = Get-AllScans $conn "Completed,Partial"
            
    Get-AllScansByDays
        Details
            Function to get all scans filtered by statuses provided as a CSV string and number of days.
            Valid Statuses are Queued, Running, Completed, Failed, Partial, Canceled
            If all Statuses are required pass $null or empty string for statuses
            Number of days must be a integer greater or equal to 0. 0 will return all days
        Parameters
            CxOneConnObj - Checkmarx One connection object
            statuses - CSV string of scan statuses to filter results
            scanDays - Integer value between 0 and 366 to specifiy the number of days to return scan for. 0 returns all scans
        Example
            $scans = Get-AllScans $conn "Completed,Partial" 90
        
    Get-LastScans
        Details
            Get the last scan for the projects provided in the projects list. 
            Optional switch to return last scan for Main Branch (if set)
        Parameters
            CxOneConnObj - Checkmarx One connection object
            projectsList - List of projects to return last of. Must be a list as provided by call above
            useMainBranch - optional switch to specify only return last scan on Main branch (if set)
        Example
            $scans = Get-LastScans $conn $projects
            
    Get-LastScansForGivenBranches
        Details
            Get the last scan for the projects provided in the projects list. 
            Returns last scan for the branch provided in the CSV file
            branchesCSV must be a file path to a CSV with the header Projects,Branches and one project,branch per line
        Parameters
            CxOneConnObj - Checkmarx One connection object
            projectsList - List of projects to return last of. Must be a list as provided by call above
            branchesCSV - file path to CSV file containing the mapping of projects to primary branch
        Example
            $scans = Get-LastScansForGivenBranches $conn $projects "C:\files\branches.csv"
            
    Get-ScanResults
        Details
            Get the results for a given scan ID
            Returns a list of result objects
        Parameters
            CxOneConnObj - Checkmarx One connection object
            scanId - The ID of the scan results to return
        Example
            $results = Get-ScanResults $conn "<scan_id>"
#>

#endregion
#----------------------------------------------------------------------------------------------------------------------------------------------------
#region Functions

# Function to take an Invoke-WebRequest or Invoke-RestMethod script block and reconnect if the token is due to expire
Function ApiCall() {
    Param(
        [Parameter(Mandatory=$true)][scriptblock]$scriptBlock,
        [Parameter(Mandatory=$true)][CxOneConnection]$conn,
        [Parameter(Mandatory=$false)][switch]$noerror
    )

    $conn.ValidateToken | Out-Null

    try {
        $response = Invoke-Command -Command $scriptBlock
        return $response
    } 
    catch [Exception] {
       if ($noerror) { throw }
       $s = $_ | Format-List * -Force | Out-String
       Write-host $s -f red
       exit
    }
}

#Function to return a CxOneConnection Object with prompt to provide API Key
Function New-Connection {
    return [CxOneConnection]::new()
}

#Function to return a CxOneConnection Object silently using provided API Key
Function New-SilentConnection {
    Param(
        [Parameter(Mandatory=$true)][string]$apikey
    )    

    return [CxOneConnection]::new($apiKey)
}

#Function to return a List of Project Objects
Function Get-AllProjects {
    Param(
        [Parameter(Mandatory=$true)][CxOneConnection]$CxOneConnObj,
        [Parameter(Mandatory=$false)][Switch]$getBranches
    )

    return ([Projects]::new($CxOneConnObj, $getBranches)).ProjectsList
}

#Function to return a filtered list of Projects using comma seperated string of names.
Function Get-ProjectsByNames {
    Param(
        [Parameter(Mandatory=$true)][CxOneConnection]$CxOneConnObj,
        [Parameter(Mandatory=$true)][AllowEmptyString()][String]$projectNames,
        [Parameter(Mandatory=$false)][Switch]$getBranches
    )

    return ([Projects]::new($CxOneConnObj, $null, $projectNames, $getBranches)).ProjectsList
}

#Function to return a filtered list of Projects using comma seperated string of IDs.
Function Get-ProjectsByIds {
    Param(
        [Parameter(Mandatory=$true)][CxOneConnection]$CxOneConnObj,
        [Parameter(Mandatory=$true)][AllowEmptyString()][String]$projectIds,
        [Parameter(Mandatory=$false)][Switch]$getBranches
    )

    return ([Projects]::new($CxOneConnObj, $projectIds, $null, $getBranches)).ProjectsList
}

#Get all scans filtered by CSV string of statuses. If all statuses are required pass $null or ""
Function Get-AllScans {
    Param(
        [Parameter(Mandatory=$true)][CxOneConnection]$CxOneConnObj,
        [Parameter(Mandatory=$true)][AllowEmptyString()][String]$statuses
    )

    return ([Scans]::new($CxOneConnObj, $statuses)).ScansList
}

#Get all scans filtered by CSV string of statuses and number of days to return. If all statuses are required pass $null or ""
Function Get-AllScansByDays {
    Param(
        [Parameter(Mandatory=$true)][CxOneConnection]$CxOneConnObj,
        [Parameter(Mandatory=$true)][AllowEmptyString()][String]$statuses,
        [Parameter(Mandatory=$true)][AllowEmptyString()][String][ValidateRange(1,366)]$scanDays
    )
    
    return ([Scans]::new($CxOneConnObj, $statuses, $scanDays)).ScansList
}

#Get the last scan for the projects provided in the projects list. 
Function Get-LastScans {
    Param(
        [Parameter(Mandatory=$true)][CxOneConnection]$CxOneConnObj,
        [Parameter(Mandatory=$true)][System.Collections.Generic.List[Project]]$projectsList,
        [Parameter(Mandatory=$false)][Switch]$useMainBranch
    )

    return ([Scans]::new($CxOneConnObj, $projectsList, $useMainBranch, $null)).ScansList
}

#Get the last scan for the projects provided in the projects list. Takes a filepath to a CSV containing the mapping of projects to branch 
Function Get-LastScansForGivenBranches {
    Param(
        [Parameter(Mandatory=$true)][CxOneConnection]$CxOneConnObj,
        [Parameter(Mandatory=$true)][System.Collections.Generic.List[Project]]$projectsList,
        [Parameter(Mandatory=$true)][AllowEmptyString()][String]$branchesCSV
    )

    return ([Scans]::new($CxOneConnObj, $projectsList, $false, $branchesCSV)).ScansList
}

#Get the results for a given scan ID
Function Get-ScanResults {
    Param(
        [Parameter(Mandatory=$true)][CxOneConnection]$CxOneConnObj,
        [Parameter(Mandatory=$true)][AllowEmptyString()][String]$scanId
    )

    return ([Results]::new($CxOneConnObj, $scanId)).ResultsList
}

#endregion
#----------------------------------------------------------------------------------------------------------------------------------------------------
#region Checkmarx One Connection Class
class CxOneConnection {
    #------------------------------------------------------------------------------------------------------------------------------------------------
    #region Variables

    #Connection Variables
    [string]$BaseURI
    [HashTable]$Headers

    #endregion
    #------------------------------------------------------------------------------------------------------------------------------------------------
    #region Hidden Variables

    #Form Variables
    Hidden [System.Windows.Forms.Form]$mainForm
    Hidden [System.Windows.Forms.Textbox]$txtBaseUri
    Hidden [System.Windows.Forms.Textbox]$txtIamUri
    Hidden [System.Windows.Forms.Textbox]$txtTenant
    Hidden [System.Windows.Forms.Textbox]$txtAPIKey
    Hidden [System.Windows.Forms.Button]$btnOK
    
    #Connection Detail for retry
    Hidden [string] $ApiKey
    Hidden [string] $IamUri
    Hidden [datetime]$TokenExpiry

    #endregion
    #------------------------------------------------------------------------------------------------------------------------------------------------
    #region Constructor

    CxOneConnection() { $this.MaunalLogin() }   
    
    CxOneConnection([string] $apikey) { $this.AutoLogin($apikey) }
    
    #endregion
    #------------------------------------------------------------------------------------------------------------------------------------------------
    #region Hidden Class Methods
    
    #Log in and set varibles using WinForm
    Hidden MaunalLogin() {
        
        Write-Verbose "Getting connection details"
        
        $this.CreateForm()
            
        $result = $this.mainForm.ShowDialog()
    
        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        
            if (-Not (($this.txtAPIKey.Text -eq "") -or ($this.txtBaseUri.Text -eq ""))) {  Write-Verbose "Connection details retrieved" }
            else { 
                Write-Host "Invalid details entered. PLease check details and try again"
                exit
            }
        }
        else { 
            Write-Host "Connection details retrieval cancelled by user. Exiting"
            exit
        } 
    }

    #Log in and set varibles using provided API Key
    Hidden AutoLogin([string]$apikey) {
        
        Write-Verbose "Getting connection details"
        
        $this.ApiKey = $apikey.Trim()
            
        # Parse the API Token provided and extract IAM URI and Tenant names
        try { $apiToken = $this.ParseJWTtoken($apikey) }
        catch { 
            Write-Host "API Key Provided is invalid" -f Red
            Write-Host "PLease check the API Key and try again" -f Red
            throw "Invalid API Key Provided"
        }
        $uri = [System.Uri]$apiToken.aud
        $this.IamUri = "https://" + $uri.Host
        $tenant = ($uri.AbsolutePath -split "/")[3]
        
        #Get Access Token, parse the token and set Base URL if successfull
        if (-not ($accessToken = $this.SetHeaders($this.IamUri, $tenant, $this.ApiKey, $true))) { 
            Write-Host "Unable to log on using API Key provided" -f Red
            Write-Host "PLease check the API Key and try again" -f Red
            throw "Invalid API Key Provided"
        }
        $keyToken = $this.ParseJWTtoken($accessToken)
        $this.BaseURI = $keyToken."ast-base-url"
    }

    #Form to get Key, Tenant and URLs from the user
    Hidden CreateForm() {
        
        # Main Form
        $this.mainForm = [System.Windows.Forms.Form]::New()
        $this.mainForm.Text = "Checkmarx One Credentials"
        $this.mainForm.Size = [System.Drawing.Size]::New(710,500)
        $this.mainForm.MaximumSize = $this.mainForm.Size
        $this.mainForm.MinimumSize = $this.mainForm.Size
        $this.mainForm.StartPosition = "CenterScreen" 
        $this.mainForm.Font = [System.Drawing.Font]::New("Segoe UI",11,[System.Drawing.FontStyle]::Regular)
    
        #region Checkmarx Icon
        $iconBase64 = "AAABAAMAEBAAAAEAIABoBAAANgAAACAgAAABACAAKBEAAJ4EAAAwMAAAAQAgAGgmAADGFQAAKAAAABAAAAAgAAAAAQAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/NWow/TRql/00a9n9M2v5/TNr+f00a9n9NWuW+jVqMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP85cQn8M2ya/TRq/v00a//9NGv//TRr//00a//9NGv//TRr//00av79NGuZ4zlVCQAAAAAAAAAAAAAAAP85cQn8NGvB/TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//40asDjOVUJAAAAAAAAAAD9M2ya/TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRrmQAAAAD/NGgx/TRq/v00a//9NGv//Ut8//7T3//9X4r//TRr//00a//9Wof//tPf//1QgP/9NGv//TRr//00av76NWow/TRqmP00a//9NGv//TRr//1Fd///5Ov//+3y//1Ofv/9Snv//+nv///n7v/9SXr//TRr//00a//9NGv//TVrlv0zatr9NGv//TRr//00a//9NGv//UV3//7S3v/+3+j//tvk//7W4f/9SHr//TRr//00a//9NGv//TRr//00a9n9NGv6/TRr//00a//9NGv//TRr//00a//9S3z///j6///7/P/9T3///TRr//00a//9NGv//TRr//00a//9M2v5/TRr+v00a//9NGv//TRr//00a//9U4L//+Pr//7P3P/+x9b//uLq//1Nff/9NGv//TRr//00a//9NGv//TNr+f0zatr9NGv//TRr//00a//9THz///H1//7h6f/9Q3b//Txx//7R3f//6e///VaE//00a//9NGv//TRr//00a9n9NGqY/TRr//00a//9NGv//UV3//64y//9UID//TRr//00a//9QnX//tvl///w9P/9YIv//TRr//00a//9NGqX/zRtMf00av79NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//1Iev//5Ov///D0//00a//9NGr+/zVqMAAAAAD9M2ub/TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//Ux8//1vlv/9NGv//DNsmgAAAAAAAAAA/zlxCfw1asL9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//DRrwf85cQkAAAAAAAAAAAAAAAD/OXEJ/TNrm/00av79NGv//TRr//00a//9NGv//TRr//00a//9NGr+/TNsmv85cQkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/NG0x/TRqmP0zatr9NGv6/TRr+v0zatr9NGqY/zRoMQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKAAAACAAAABAAAAAAQAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/N20O/DRqWf0zbJr+NGvL/TNr6v00a/v9NGv7/TNr6vw0a8v8M2qa/DRrWP83bQ4AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD4MGcl/DRrnf00a/b9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr9f01a5v/MmokAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/OXEJ+zNrjP00a/r9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a/r9NGuK/0BgCAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/zJqJP40bNP9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//+NGvS+DNmIwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP81ajD9NGvq/TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9M2vq/zJpLgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD4MGcl/TRr6v00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9M2vq+DNmIwAAAAAAAAAAAAAAAAAAAAAAAAAA/zlxCf00a9T9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//+NGvS/0BgCAAAAAAAAAAAAAAAAAAAAAD9M2uN/TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGuKAAAAAAAAAAAAAAAA/y9rJv00a/v9NGv//TRr//00a//9NGv//TRr//00a//9O3D//qS9//6swv/9QnX//TRr//00a//9NGv//TRr//00a//9NGv//T1x//6mvv/+qsH//UBz//00a//9NGv//TRr//00a//9NGv//TRr//00a/r/MmokAAAAAAAAAAD9NGue/TRr//00a//9NGv//TRr//00a//9NGv//TRr//6Lqv////////////7O2//9OW///TRr//00a//9NGv//TRr//02bf/+wtP////////////+mbX//TRr//00a//9NGv//TRr//00a//9NGv//TRr//01a5sAAAAA/zNmD/40a/b9NGv//TRr//00a//9NGv//TRr//00a//9NGv//nic//////////////////63y//9NWv//TRr//00a//9NGv//qnA//////////////////6Hp//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr9f83bQ78Mmpb/TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//pOw///+/v////////////6ct//9NGv//TRr//6NrP/////////////////+obr//TVs//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//DRrWP00apz9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//Xic///4+v////////////2Ao//9c5n///39/////////Pz//YWm//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//8M2qa/jRrzf00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//WKM///u8/////////7+///8/f////////P2//1slP/9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//w0a8v9NGvs/TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//U9////r8f/////////////09//9WIX//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TNr6v00a/79NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9d5v///n6//////////////z9//19oP/9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv7/TRr/v00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//pKv///+/v///////+3x///n7v////////7+//2Lq//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a/v9NGvs/TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//Tdt//6uxP/////////////1+P/9W4f//U19///p7/////////////6atf/9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TNr6v00as79NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//08cf/+x9b//////////////P3//W+W//00a//9NGv//VaE///w9P////////////6pwf/9NWz//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//+NGvL/DRrnf00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//oyr//////////////////2Jqf/9NGv//TRr//00a//9NGv//WCL///2+P////////////64y//9OG7//TRr//00a//9NGv//TRr//00a//9NGv//TRr//0zbJr8NWlc/TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//+d5z////////////+pL3//TRr//00a//9NGv//TRr//00a//9NGv//WuT///6+/////////////7F1f/9PHH//TRr//00a//9NGv//TRr//00a//9NGv//DRqWe8wYBD9NGr3/TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9bJT//XWa//01a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//Xec///9/f////////////7Q3f/9QXT//TRr//00a//9NGv//TRr//00a/b/N20OAAAAAP0za5/9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//YSm///+/v////////////7N2v/9NGv//TRr//00a//9NGv//DRrnQAAAAAAAAAA/zRpJ/00a/v9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//pSx//////////////X4//00a//9NGv//TRr//00a/r4MGclAAAAAAAAAAAAAAAA/TRqjv00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//pOw//7V4f/9fqH//TRr//00a//9NGv/+zNrjAAAAAAAAAAAAAAAAAAAAAD/M2YK/TNr1f00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//40bNP/OXEJAAAAAAAAAAAAAAAAAAAAAAAAAAD/Nmsm/TRq6/00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGvq/zJqJAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD6Nmc0/TRq6/00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr6v81ajAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/Nmsm/TNr1f00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a9T4MGclAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/M2YK/TRqjv00a/v9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a/v9M2uN/zlxCQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/zRpJ/0za5/9NGr3/TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//40a/b9NGue/y9rJgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAO8wYBD8NWlc/DRrnf00as79NGvs/TRr/v00a/79NGvs/jRrzf00apz8Mmpb/zNmDwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKAAAADAAAABgAAAAAQAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP8AgALwLWkR/zRpIvs1akj9NGqE/DRstP0zatb+NGzt/TRr+/00a/v9NGzt/jNr1fw0arT7M2uD+zJsR/80aSL/MHAQ/wCAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/QIAE/zRtMf00a3X8NGux/TRr5f00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//41a+T8NGuw/TVsdP81ajD/QEAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAPYzbh78NGqd/TRr4/00a/r9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr+v00a+L9M2ya/zdtHAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP8AAAHzMW0V/TRscf0zavP9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr8f0yaXD/M2YU/wAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP81az78NGu3/TRr+v00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a/r+NGu1/zNqPAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/AAAB/DRsY/00a+j9NGv+/TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv+/jRr5/wza1//AAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP8kbQf6M2pv/TRr8/00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//0za/P9M2lt/yqABgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/wAAAf0zam/9NGvs/TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGrr/TNpbf8AAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/DNrZP40a/P9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TNr8/wza18AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP8AAAH7NWk//TRr6P00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//40a+f/M2o8/wAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP8xbRX8M2u4/TRr/v00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a/7+NGu1/zNmFAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP0zanP9NGv6/TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv6/TJpcAAAAAAAAAAAAAAAAAAAAAAAAAAA9zFrH/0za/P9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//Thu//1fi//9jKv//WmS//08cf/9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//Tlu//1ijP/9jaz//WeQ//07cP/9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr8f83bRwAAAAAAAAAAAAAAAD/QIAE/DNrn/00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//X6h///1+P////////r8//6guf/9PXL//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9OW///pCu///2+P////////n7//6Rr//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//0zbJr/QEAEAAAAAAAAAAD6Mmkz/jRr4/00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//9Le///////////////////2+f/+jKv//Tdt//00a//9NGv//TRr//00a//9NGv//TRr//01bP/9fqH///L1///////////////////d5v/9PnL//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a+L/NWowAAAAAP8AgAL/NGx2/TRr+v00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//73P////////////////////////8PT//WyU//00a//9NGv//TRr//00a//9NGv//TRr//1hi///5u3////////////////////////R3f/9OW7//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a/r9NWx0/wCAAv8taRH8M2uz/TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//VqH///V4f///////////////////////+fu//1okP/9NGv//TRr//00a//9NGv//VqH///c5v///////////////////////+Hp//1okf/9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//8NGuw/zBwEP8zbSP9NGvn/TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//1Sgf/+yNf///7////////////////////e5//9W4f//TRr//00a//9T3///9Xg////////////////////////1eD//VqH//01a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//+NWvk/zRpIv8zaUv9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9SXr//sPT///7/P/////////////////+xdT//Ul6//1Ddv/+t8v///7+//////////////3+//7P3P/9U4H//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv/+zJsR/0zbIf9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//UF1//6jvP//8/f//////////////f3//rvN//6vxf//+vv/////////////+Pr//rDF//1Jev/9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv/+zNrg/41arf9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//08cf/+jq3///b4//////////////7+///+/v/////////////5+v/+nbf//UB0//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//DRqtP4zatr9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//oCi///09/////////////////////////n6//6TsP/9N23//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//jNr1f0za/P9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//UF0///U3////////////////////////+fu//1Ief/9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRs7f00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9SHr//sHS///8/P////////////////////////3+//7I1//9Snv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr+/00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//1Sgf/+x9b///7///////////////X3///y9f/////////////+///+xdT//U9+//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr+/0za/P9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NWz//WqS///V4P//////////////////8PT//oio//56nv//5ez//////////////v7//s3a//1bh//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//jRs7f0za9v9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//02bP/9eZ7//+ju///////////////////6+//+mbX//Tpv//03bf/+faH///P2///////////////////d5v/9Y43//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TNq1v41a7j9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//Tlu//1/ov//8vX///////////////////7+//66zP/9PHH//TRr//00a//9NGv//pGv///2+f//////////////////3+j//WGM//01bP/9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//DRstPsza4j9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//YGj///4+v///////////////////v7//r7Q//1Ddv/9NGv//TRr//00a//9NGv//TVs//6Rrv//8/b//////////////////+Tr//13nP/9Nm3//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRqhP8ya0z9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//9Tf///////////////////////+zNr//U19//00a//9NGv//TRr//00a//9NGv//TRr//07cP/+nLf///r7///////////////////t8v/9gKL//Tdt//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv/+zVqSP8zbSP9NGvo/TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//77Q///////////////////j6v/9Yoz//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9PHH//rLH///8/f//////////////////8vX//Xuf//04bv/9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGvl/zRpIvE5YxL8NGq0/TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//VmG//7F1f/+6O7//tDd//1ulf/9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//UBz//6vxf//+/z///////////////////b5//6Sr//9P3P//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//8NGux8C1pEf8AgAL9M2t3/TRr+/00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//1Cdv/9Tn7//UZ4//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//1Ed//+ucz///7+///////////////////3+f/+nbj//Ttw//00a//9NGv//TRr//00a//9NGv//TRr//00a/r9NGt1/wCAAgAAAAD/Mmkz/TNr5P00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9S3z//s/c/////////////////////////f3//Y+t//00a//9NGv//TRr//00a//9NGv//TRr//00a+P/NG0xAAAAAAAAAAD/QIAE/TRqof00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//VB///7N2v///////////////////////+zx//00a//9NGv//TRr//00a//9NGv//TRr//w0ap3/QIAEAAAAAAAAAAAAAAAA/zhwIP00a/T9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//1Tgv//0t///////////////////ubt//00a//9NGv//TRr//00a//9NGv//TNq8/Yzbh4AAAAAAAAAAAAAAAAAAAAAAAAAAP80a3X9NGv7/TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9Y43//9nj///x9f//6e7//Xqe//00a//9NGv//TRr//00a//9NGv6/TRscQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP86aBb8NGu6/TRr/v00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//U9+//1xmP/9W4f//Tdt//00a//9NGv//TRr//00a/78NGu38zFtFQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP8AAAH/NGxA/TNr6f00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a+j/NWs+/wAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/zNsaP00a/T9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr8/w0bGMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/wCAAvszaXL9NGvv/TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGvs+jNqb/8AAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP9AYAj7M2ly/TRr9P00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//40a/P9M2pv/yRtBwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/AIAC/zNsaP0za+n9NGv+/TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv+/TRr6Pwza2T/AAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP80bED8NGu6/TRr+/00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a/r8M2u4+zVpPwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP8AAAH/OmgW/zRrdf00a/T9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TNr8/0zanP/MW0V/wAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP84cCD9NGqh/TNr5P00a/v9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr+v40a+P8M2uf9zFrHwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/QIAE/zJpM/0za3f8NGq0/TRr6P00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a//9NGv//TRr//00a+f8M2uz/zRsdvoyaTP/QIAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP8AgALxOWMS/zNtI/8ya0z7M2uI/jVruP0za9v9M2vz/TRr//00a//9M2vz/jNq2v41arf9M2yH/zNpS/8zbSP/LWkR/wCAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=="
        #endregion
        $iconBytes = [Convert]::FromBase64String($iconBase64)
        $stream = [IO.MemoryStream]::New($iconBytes, 0, $iconBytes.Length)
        $this.mainForm.Icon = [System.Drawing.Icon]::FromHandle(([System.Drawing.Bitmap]::New($stream)).GetHIcon())
        $stream.Dispose()
    
        # Base Region texbox Label
        $lblBaseUri = [System.Windows.Forms.Label]::New()
        $lblBaseUri.Text = "Base URL"
        $lblBaseUri.Location = [System.Drawing.Point]::New(15,20)
        $this.mainForm.Controls.Add($lblBaseUri)
        
        # Base URL Textbox
        $this.txtBaseUri = [System.Windows.Forms.Textbox]::New()
        $this.txtBaseUri.Location = [System.Drawing.Point]::New(120,20)
        $this.txtBaseUri.Size = [System.Drawing.Size]::New(312,30)
        $this.txtBaseUri.Enabled = $false
        $this.mainForm.Controls.Add($this.txtBaseUri)
    
        # IAM URL texbox Label
        $lblIamUri = [System.Windows.Forms.Label]::New()
        $lblIamUri.Text = "IAM URL"
        $lblIamUri.Location = [System.Drawing.Point]::New(15,63)
        $this.mainForm.Controls.Add($lblIamUri)
    
        # IAM URL Textbox
        $this.txtIamUri = [System.Windows.Forms.Textbox]::New()
        $this.txtIamUri.Location = [System.Drawing.Point]::New(120,63)
        $this.txtIamUri.Size = [System.Drawing.Size]::New(312,30)
        $this.txtIamUri.Enabled = $false
        $this.mainForm.Controls.Add($this.txtIamUri)
    
        # Tenant texbox Label
        $lblTenant = [System.Windows.Forms.Label]::New()
        $lblTenant.Text = "Tenant"
        $lblTenant.Location = [System.Drawing.Point]::New(15,106)
        $this.mainForm.Controls.Add($lblTenant)
    
        # Tenant Textbox
        $this.txtTenant = [System.Windows.Forms.Textbox]::New()
        $this.txtTenant.Location = [System.Drawing.Point]::New(120,106)
        $this.txtTenant.Size = [System.Drawing.Size]::New(312,30)
        $this.txtTenant.Enabled = $false
        $this.mainForm.Controls.Add($this.txtTenant)
    
        # API Key label 
        $lblAPIKey = [System.Windows.Forms.Label]::New()
        $lblAPIKey.Text = "API Key"
        $lblAPIKey.Location = [System.Drawing.Point]::New(15,149)
        $this.mainForm.Controls.Add($lblAPIKey)

        # API Key Changed
        $txtAPIKey_TextChanged =  {
            [CxOneConnection]$cd = Get-Variable -ValueOnly -Scope 1 this
            if ($cd.txtAPIKey.Text -eq "") {
                $cd.ClearForm()
                return
            }      
            
            #Try parsing the API Key and set IAM and Tenant text boxes
            if (-not ($apiToken = $cd.TryParseToken($cd.txtAPIKey.Text.Trim()))) { return }
            $uri = [System.Uri]$apiToken.aud
            $cd.txtIamUri.Text = "https://" + $uri.Host
            $cd.txtTenant.Text = ($uri.AbsolutePath -split "/")[3]

            #Get Access Token, parse the token and set Base URL Text box if successfull
            if (-not ($accessToken = $cd.SetHeaders($cd.txtIamUri.Text, $cd.txtTenant.Text, $cd.txtAPIKey.Text.Trim(), $false))) { 
                $cd.ClearForm()
                return 
            }
            $keyToken = $cd.TryParseToken($accessToken)
            $cd.txtBaseUri.Text = $keyToken."ast-base-url"
            
            #Set Class Variables
            $cd.BaseUri = $keyToken."ast-base-url"
            $cd.ApiKey = $cd.txtAPIKey.Text.Trim()
            $cd.IamUri = $cd.txtIamUri.Text
            $cd.TokenExpiry = ([DateTime]('1970,1,1')).AddSeconds($keyToken."exp")
            
            $cd.btnOK.Enabled = $true
        }

        # API Key Textbox
        $this.txtAPIKey = [System.Windows.Forms.Textbox]::New()
        $this.txtAPIKey.Location = [System.Drawing.Point]::New(120,149)
        $this.txtAPIKey.Size = [System.Drawing.Size]::New(552,229)
        $this.txtAPIKey.Multiline = $true
        $this.txtAPIKey.Add_TextChanged($txtAPIKey_TextChanged)
        $this.mainForm.Controls.Add($this.txtAPIKey)
    
        # OK Button
        $this.btnOK = [System.Windows.Forms.Button]::New()
        $this.btnOK.Text = "OK"
        $this.btnOK.Location = [System.Drawing.Point]::New(467,417)
        $this.btnOK.Size = [System.Drawing.Size]::New(96,34)
        $this.btnOK.Enabled = $false
        $this.btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $this.mainForm.Controls.Add($this.btnOK)
    
        # Cancel Button
        $btnCancel = [System.Windows.Forms.Button]::New()
        $btnCancel.Text = "Cancel"
        $btnCancel.Location = [System.Drawing.Point]::New(576,417)
        $btnCancel.Size = [System.Drawing.Size]::New(96,34)
        $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $this.mainForm.Controls.Add($btnCancel)
    }

    #Method to parse the API Key
    Hidden [PSObject]ParseJWTtoken([string]$token) {
        #https://www.michev.info/blog/post/2140/decode-jwt-access-and-id-tokens-via-powershell
     
        Write-Verbose "Decoding token"
    
        #Validate as per https://tools.ietf.org/html/rfc7519
        #Access and ID tokens are fine, Refresh tokens will not work
        if (!$token.Contains(".") -or !$token.StartsWith("eyJ")) { Throw "Invalid Token" }
     
        #Header
        $tokenheader = $token.Split(".")[0].Replace('-', '+').Replace('_', '/')
        #Fix padding as needed, keep adding "=" until string length modulus 4 reaches 0
        while ($tokenheader.Length % 4) { Write-Verbose "Invalid length for a Base-64 char array or string, adding ="; $tokenheader += "=" }
    
        #Convert from Base64 encoded string to PSObject all at once
        #[System.Text.Encoding]::ASCII.GetString([system.convert]::FromBase64String($tokenheader)) | ConvertFrom-Json | fl | Out-Default
     
        #Payload
        $tokenPayload = $token.Split(".")[1].Replace('-', '+').Replace('_', '/')
        #Fix padding as needed, keep adding "=" until string length modulus 4 reaches 0
        while ($tokenPayload.Length % 4) { Write-Verbose "Invalid length for a Base-64 char array or string, adding ="; $tokenPayload += "=" }
    
        #Convert to Byte array
        $tokenByteArray = [System.Convert]::FromBase64String($tokenPayload)
        #Convert to string array
        $tokenArray = [System.Text.Encoding]::ASCII.GetString($tokenByteArray)
    
        #Convert from JSON to PSObject
        $tokobj = $tokenArray | ConvertFrom-Json
        
        Write-Verbose "Token decoded"
    
        return $tokobj
    }

    #Try parsing the provided token. Clear form and return null on fail
    Hidden [PSObject]TryParseToken([string]$token) {
        try {
            return $this.ParseJWTtoken($token)
        }
        catch {
            $this.ClearForm()
            return $null
        }
    }

    #Clear the form when invalid details
    Hidden ClearForm() {
        $this.txtIamUri.Text = ""
        $this.txtBaseUri.Text = ""
        $this.txtTenant.Text = ""
        $this.btnOK.Enabled = $false
    }

    #Create the Hash for use as the Header. Returns the Access Token on success and null on fail
    Hidden [string]SetHeaders([string]$iamurl, [string]$tenant, [string]$apikey, [bool]$setExpiry) {

        Write-Verbose "Starting Authentication"       
        
        #Get Access token
        $uri = "$iamurl/auth/realms/$tenant/protocol/openid-connect/token"
        $body = @{
            grant_type = "refresh_token"
            client_id = "ast-app"  
            refresh_token = $apikey
        }
        try {
            $accessToken = (Invoke-RestMethod -Uri $uri -Method POST -Body $body).access_token
        }
        catch {
            Write-Verbose "Error authenticating."
            return $null
        }
    
        Write-Verbose "Authentication Completed"
        
        $this.Headers = @{
            accept = "application/json; version=1.0"
            Authorization = "Bearer $accessToken"
        }

        if ($setExpiry) {
            $keyToken = $this.ParseJWTtoken($accessToken)
            $this.TokenExpiry = ([DateTime]('1970,1,1')).AddSeconds($keyToken."exp")
        }

        return $accessToken
    }
    
    Hidden Reconnect() {

        if ($null -eq $this.ApiKey -or $null -eq $this.IamUri) {
            Write-Host "API Key or IAM URI not set. Exiting"
            exit
        }
 
        Write-Verbose "Token Has expired, regenerating token"
        $this.SetHeaders($this.IamUri, $this.IamUri, $this.ApiKey, $true)
        Write-Verbose "Token regenerated"
    }
    
    #endregion
    #------------------------------------------------------------------------------------------------------------------------------------------------
    #region Public Class Methods
   
    # Function to test if token due to expire and reconnect if needed
    ValidateToken() {

        #Reconnect if token due to expire in the next 5 minutes
        if ([DateTime]::UtcNow -ge $this.TokenExpiry.AddMinutes(-5)) { $this.Reconnect() }
    }

    #endregion
    #------------------------------------------------------------------------------------------------------------------------------------------------
}

#endregion
#----------------------------------------------------------------------------------------------------------------------------------------------------
#region Projects Classes

class Project {
    #---------------------------------------------------------------------------------------------------------------------------------------
    #region Variables
    
    [String]$ProjectID
    [String]$ProjectName
    [String]$TenantId
    [DateTime]$CreatedAt
    [DateTime]$UpdatedAt
    [Array]$Groups
    [string]$GroupsString
    [String]$RepoURL
    [String]$MainBranch
    [String]$Origin
    [System.Collections.IDictionary]$Tags
    [string]$TagsString
    [Int]$Criticality
    [Bool]$PrivatePackage
    [String]$ImportedProjName
    [Array]$Branches
    [string]$BranchesString
 
    #endregion    
    #--------------------------------------------------------------------------------------------------------------------------------------
    #region Constructors

    Project ([System.Collections.IDictionary]$project) { $this.SetVariables($project) }

    #endregion
    #--------------------------------------------------------------------------------------------------------------------------------------
    #region Hidden Methods
    
    [void] Hidden SetVariables([System.Collections.IDictionary]$project) {
           
        try { $this.ProjectId = $project.id }
        catch { $this.ProjectId = $null }
            
        try { $this.ProjectName = $project.name }
        catch { $this.ProjectName = $null }
    
        try { $this.TenantId = $project.tenantId }
        catch { $this.TenantId = $null }
    
        try { $this.CreatedAt = [DateTime]$project.createdAt }
        catch { $this.CreatedAt = $null }
    
        try { $this.UpdatedAt = [DateTime]$project.updatedAt }
        catch { $this.UpdatedAt = $null }
            
        try { 
            $this.Groups = $project.groups
            $this.Groups = ($project.groups) -join ";"
        }
        catch { $this.Groups = $null }
            
        try { $this.RepoURL = $project.repoURL }
        catch { $this.RepoURL = $null }
            
        try { $this.MainBranch = $project.mainBranch }
        catch { $this.MainBranch = $null }
            
        try { $this.Origin = $project.origin }
        catch { $this.Origin = $null }
  
        try { 
            $this.Tags = $project.tags
            $this.TagsString = $null
            foreach ($tag in $project.tags.GetEnumerator()) { 
                if ($null -ne $this.BranchesString) { $this.BranchesString += ";" }
                if ($tag.Value -eq "") { $this.TagsString += $tag.Key }
                else { $this.TagsString += $tag.Key + ":" + $tag.Value }     
            }
        }
        catch { 
            $this.Tags = $null
            $this.TagsString = $null 
        }

        try { $this.Criticality = $project.criticality }
        catch { $this.Criticality = $null }
    
        try { $this.PrivatePackage = [bool]$project.privatePackage }
        catch { $this.PrivatePackage = $null }
            
        try { $this.ImportedProjName = $project.imported_proj_name }
        catch { $this.ImportedProjName = $null }
    }

    #endregion    
    #--------------------------------------------------------------------------------------------------------------------------------------
    #region Public Methods
    
    [void] AddBranches([Array]$branches) {
        $this.Branches += $branches
        foreach ($branch in $branches) { 
            if ($null -ne $this.BranchesString) { $this.BranchesString += ";" }
            $this.BranchesString += $branch
        }
    }

    #endregion    
    #--------------------------------------------------------------------------------------------------------------------------------------
}

class Projects {
    #--------------------------------------------------------------------------------------------------------------------------------------
    #region Variables

    [System.Collections.Generic.List[Project]]$ProjectsList

    #endregion
    #--------------------------------------------------------------------------------------------------------------------------------------
    #region Hidden Variables

    Hidden [Int]$Offset
    Hidden [Int]$Limit
    Hidden [Int]$FilteredTotalCount
    Hidden [Int]$TotalCount

    #endregion
    #--------------------------------------------------------------------------------------------------------------------------------------
    #region Constructors

    #Get All Projects
    Projects([CxOneConnection]$conn, [switch]$getBranches) { $this.GetProjectList($conn, $null, $null, $getBranches) }
    
    #Get filtered List of projects - Using both Name and ID will not return any values
    Projects([CxOneConnection]$conn, [String]$projectIds, [String]$projectNames, [switch]$getBranches) { 
        $this.GetProjectList($conn, $projectIds, $projectNames, $getBranches)
    }
    
    #endregion
    #--------------------------------------------------------------------------------------------------------------------------------------
    #region Hidden Methods

    [void] Hidden GetProjectList([CxOneConnection]$conn, [String]$projectIds, [String]$projectNames, [switch]$getBranches) {
        
        Write-Verbose "Retrieving projects"
        
        $this.Offset = 0
        $this.Limit = 100

        $this.projectsList = [System.Collections.Generic.List[Project]]::New()

        do {
    
            Write-Verbose "Retrieving projects Offset=$($this.Offset)"
        
            $uri = "$($conn.baseUri)/api/projects/?offset=$($this.Offset)&limit=$($this.Limit)"
        
            if ($projectNames) {
                $projectNames -split "," | ForEach-Object { $uri += "&names=$([uri]::EscapeUriString($_))" }
            }

            if ($projectIds) {
                $projectIds -split "," | ForEach-Object { $uri += "&ids=$([uri]::EscapeUriString($_))" }
            }
            
            $response = ApiCall { Invoke-WebRequest $uri -Method GET -Headers $conn.Headers} $conn
            $json = ([System.Web.Script.Serialization.JavaScriptSerializer]::New()).DeserializeObject($response) 
        
            if ($this.Offset -eq 0) { 
                $this.FilteredTotalCount = $json.filteredTotalCount
                $this.TotalCount = $json.totalCount   
            }

            foreach ($p in $json.projects) { $this.ProjectsList.Add([Project]::new($p)) }

            Write-Verbose "$($this.Limit) Projects Retrieved with Offset: $($this.Offset)"
            $this.Offset += $this.Limit
            
        } while ($this.Offset -lt $this.filteredTotalCount)

        if ($getBranches) { $this.GetBranches($conn) }
    }

    [void] Hidden GetBranches([CxOneConnection]$conn) {
        
        foreach ($p in $this.ProjectsList) {
            
            $this.Offset = 0
            $this.Limit = 100
            $continue = $false
            
            do {
                $uri = "$($conn.baseUri)/api/projects/branches?offset=$($this.Offset)&limit=$($this.Limit)&project-id=$($p.ProjectID)"
                $response = ApiCall { Invoke-RestMethod $uri -Method GET -Headers $conn.Headers } $conn

                if ($response -ne "null") {
                    $p.AddBranches($response)
                    $this.Offset += $this.Limit
                    $continue = $true
                }
                else { $continue = $false }
            
            } while ($continue)
        }
    }

    #endregion
    #--------------------------------------------------------------------------------------------------------------------------------------
}

#endregion
#----------------------------------------------------------------------------------------------------------------------------------------------------
#region Scans

Class Scan {
    #---------------------------------------------------------------------------------------------------------------------------------------
    #region Variables

    [string]$ScanID
    [string]$ProjectId
    [string]$ProjectName
    [string]$Status
    [string]$Branch
    [DateTime]$CreatedAt
    [DateTime]$UpdatedAt
    [Array]$Engines
    [string]$EnginesString
    [string]$UserAgent
    [string]$Initiator
    [System.Collections.IDictionary]$Tags
    [string]$TagsString
    [string]$SourceType
    [string]$SourceOrigin

    #endregion    
    #--------------------------------------------------------------------------------------------------------------------------------------
    #region Constructors

    Scan() {}

    Scan ([System.Collections.IDictionary]$scan) { $this.SetVariables($scan) }

    #endregion
    #--------------------------------------------------------------------------------------------------------------------------------------
    #region Hidden Methods

    [void] Hidden SetVariables([System.Collections.IDictionary]$scan) {
           
        try { $this.ScanID = $scan.id }
        catch { $this.ScanID = $null }

        try { $this.ProjectId = $scan.projectId }
        catch { $this.ProjectId = $null }

        try { $this.ProjectName = $scan.projectName }
        catch { $this.ProjectName = $null }

        try { $this.Status = $scan.status }
        catch { $this.Status = $null }

        try { $this.Branch = $scan.branch }
        catch { $this.Branch = $null }

        try { $this.CreatedAt = [DateTime]$scan.createdAt }
        catch { $this.CreatedAt = $null }

        try { $this.UpdatedAt = [DateTime]$scan.updatedAt }
        catch { $this.UpdatedAt = $null }

        try { 
            $this.Engines = $scan.engines
            $this.EnginesString = (($scan.engines) -join ",")
        }
        catch { 
            $this.Tags = $null
            $this.TagsString = $null 
        }

        try { $this.UserAgent = $scan.userAgent }
        catch { $this.UserAgent = $null }
        
        try { $this.Initiator = $scan.initiator }
        catch { $this.Initiator = $null }

        try { 
            $this.Tags = $scan.tags
            $this.TagsString = $null
            foreach ($tag in $scan.tags.GetEnumerator()) { 
                if ($null -ne $this.TagsString) { $this.TagsString += ";" }
                if ($tag.Value -eq "") { $this.TagsString += $tag.Key }
                else { $this.TagsString += $tag.Key + ":" + $tag.Value }     
            }
        }
        catch { 
            $this.Tags = $null
            $this.TagsString = $null 
        }

        try { $this.SourceType = $scan.sourceType }
        catch { $this.SourceType = $null }

        try { $this.SourceOrigin = $scan.sourceOrigin }
        catch { $this.SourceOrigin = $null }
    }
    
    #endregion    
    #--------------------------------------------------------------------------------------------------------------------------------------
}

class Scans {
    #------------------------------------------------------------------------------------------------------------------------------------------------
    #region Variables

    [System.Collections.Generic.List[Scan]]$ScansList
    [Int]$FilteredTotalCount
    [Int]$TotalCount

    #endregion
    #------------------------------------------------------------------------------------------------------------------------------------------------
    #region Hidden Variables

    Hidden [Int]$Offset = 0
    Hidden [Int]$Limit = 100

    #endregion
    #------------------------------------------------------------------------------------------------------------------------------------------------
    #region Constructors

    #Get All Scans
    Scans() {}
    
    Scans([CxOneConnection]$conn) { $this.GetScansList($conn, $null) }

    Scans([CxOneConnection]$conn, [System.Collections.Generic.List[Project]]$projectsList, [Switch]$useMainBranch, [String]$branchesCSV) { 
        $this.GetLastScansList($conn , $projectsList, $useMainBranch, $branchesCSV)
    }
    
    #Get List of scans using a comma seperated string of statuses to filter by
    Scans([CxOneConnection]$conn, [String]$statuses) { $this.GetScansList($conn, $statuses, 0) }

    #Get List of scans using a comma seperated string of statuses to filter by and number of days to retrieve
    Scans([CxOneConnection]$conn, [String]$statuses, [Int]$scanDays) { $this.GetScansList($conn, $statuses, $scanDays) }
    
    #endregion
    #------------------------------------------------------------------------------------------------------------------------------------------------
    #region Hidden Methods
    
    [void] Hidden GetScansList([CxOneConnection]$conn, [String]$statuses, [Int]$scanDays) {
        
        Write-Verbose "Retrieving scans"

        $this.ScansList = [System.Collections.Generic.List[Scan]]::New()
        
        if ($scanDays) { $fromDate = [uri]::EscapeDataString(([datetime]::Today).AddDays(-$scanDays).ToString("yyyy-MM-ddThh:mm:ss.fffffffZ")) }

        do {
    
            Write-Verbose "Retrieving scans Offset=$($this.Offset)"
        
            $uri = "$($conn.baseUri)/api/scans/?offset=$($this.Offset)&limit=$($this.Limit)"
            if ($scanDays) { $uri += "&from-date=$fromDate" }
        
            if ($statuses) { $uri += "&statuses=$statuses" }
           
            $response = ApiCall { Invoke-WebRequest $uri -Method GET -Headers $conn.Headers} $conn
            $json = ([System.Web.Script.Serialization.JavaScriptSerializer]::New()).DeserializeObject($response) 
        
            if ($this.Offset -eq 0) { 
                $this.FilteredTotalCount = $json.filteredTotalCount
                $this.TotalCount = $json.totalCount   
            }

            foreach ($p in $json.scans) { $this.ScansList.Add([Scan]::new($p)) }

            Write-Verbose "$($this.Limit) Scans Retrieved with Offset: $($this.Offset)"
            $this.Offset += $this.Limit
            
        } while ($this.Offset -lt $this.filteredTotalCount)
    }

    [void] Hidden GetLastScansList([CxOneConnection]$conn, [System.Collections.Generic.List[Project]]$projectsList,
                                   [switch] $useMainBranch, [string]$branchesCSV) {

        $this.ScansList = [System.Collections.Generic.List[Scan]]::New()
        $branches = @()

        #Load branaches filter from csv if present
        if (-NOT $useMainBranch -AND -NOT [string]::IsNullOrEmpty($branchesCSV)) {
            Write-Verbose "Retrieving branches listing from branches CSV"
            try { $branches = Import-Csv -Path $branchesCSV }
            catch {
                $s = $_ | Format-List * -Force | Out-String
                Write-host $s -f red
                exit
            }
            Write-Verbose "branches listing loaded"
        }

        foreach ($p in $projectsList) {

            $uri = "$($conn.BaseURI)/api/projects/last-scan?project-ids=$($p.ProjectID)&scan-status=Completed&use-main-branch=$($useMainBranch.toString())"
    
            if ($branches) {
                $branchName = ($branches | Where-Object { $_.Projects -eq $p.ProjectName }).Branches
                if ($branchName -Is [Array]) {
                    Write-host "The file $branchesCSV can only contain one entry per project. PLease correct and retry" -f red
                    exit
                }
                if (-NOT [string]::IsNullOrEmpty($branchName)) { $uri += "&branch=$branchName" }
            }

            $response = ApiCall { Invoke-WebRequest $uri -Method GET -Headers $conn.Headers } $conn
            $json = ([System.Web.Script.Serialization.JavaScriptSerializer]::New()).DeserializeObject($response)
            $scan = $json[$p.projectId]
            $scan.Add("projectId", $p.projectId)
            $scan.Add("projectName", $p.ProjectName)

            $this.ScansList.Add([Scan]::new($scan)) 
        }
    }

    #endregion
    #------------------------------------------------------------------------------------------------------------------------------------------------
}

#endregion
#----------------------------------------------------------------------------------------------------------------------------------------------------
#region Results Classes

class Result {
    #--------------------------------------------------------------------------------------------------------------------------------------
    #region Variables
    
    [string]$Type
	[string]$SimilarityId
	[string]$Status
	[string]$State
	[string]$Severity
	[DateTime]$Created
	[DateTime]$FirstFoundAt
	[DateTime]$FoundAt
	[string]$Description
	[string]$QueryName
	[string]$Group
	[string]$LanguageName
	[string]$CweId
    [string]$Comments

    #endregion
    #--------------------------------------------------------------------------------------------------------------------------------------
    #region Constructors

    Result() {}

    Result ([PSCustomObject]$result) { $this.SetVariables($result) }

    #endregion
        #--------------------------------------------------------------------------------------------------------------------------------------
    #region Hidden Methods
    
    [void] Hidden SetVariables([PSCustomObject]$result) {
           
        try { $this.Type = $result.type }
        catch { $this.Type = $null }

        try { $this.SimilarityId = $result.similarityId }
        catch { $this.SimilarityId = $null }

        try { $this.Status = $result.status }
        catch { $this.Status = $null }

        try { $this.State = $result.state }
        catch { $this.State = $null }

        try { $this.Severity = $result.severity }
        catch { $this.Severity = $null }
        
        try { $this.Created = [DateTime]$result.created }
        catch { $this.Created = $null }

        try { $this.FirstFoundAt = [DateTime]$result.firstFoundAt }
        catch { $this.FirstFoundAt = $null }

        try { $this.FoundAt = [DateTime]$result.foundAt }
        catch { $this.FoundAt = $null }

        try { $this.Description = $result.description }
        catch { $this.Description = $null }

        try { $this.QueryName = $result.data.queryName }
        catch { $this.QueryName = $null }

        try { $this.Group = $result.data.group }
        catch { $this.SeveriGroupty = $null }

        try { $this.LanguageName = $result.data.languageName }
        catch { $this.LanguageName = $null }

        try { $this.CweId = $result.vulnerabilityDetails.cweId }
        catch { $this.CweId = $null }

        try { $this.Comments = $result.comments }
        catch { $this.Comments = $null }
    }

    #endregion    
    #--------------------------------------------------------------------------------------------------------------------------------------
}

Class Results {
    #------------------------------------------------------------------------------------------------------------------------------------------------
    #region Variables

    [System.Collections.Generic.List[Result]]$ResultsList
    [Int]$TotalCount

    #endregion
    #------------------------------------------------------------------------------------------------------------------------------------------------
    #region Hidden Variables

    Hidden [Int]$Offset = 0
    Hidden [Int]$Limit = 20

    #endregion
    #------------------------------------------------------------------------------------------------------------------------------------------------
    #region Constructors

    #Get All Results 
    Results([CxOneConnection]$conn, [String]$scanId) { $this.GetResultsList($conn, $scanId) }
    
    #endregion
    #------------------------------------------------------------------------------------------------------------------------------------------------
    #region Hidden Methods

    [void] Hidden GetResultsList([CxOneConnection]$conn, [String]$scanId) {
        
        Write-Verbose "Retrieving projects"

        $this.ResultsList = [System.Collections.Generic.List[Result]]::New()

        do {
    
            Write-Verbose "Retrieving results Offset=$($this.Offset)"
        
            $uri = "$($conn.baseUri)/api/results/?scan-id=$scanId&offset=$($this.Offset)&limit=$($this.Limit)"
            
            $response = ApiCall { Invoke-RestMethod $uri -Method GET -Headers $conn.Headers } $conn
        
            if ($this.Offset -eq 0) { $this.TotalCount = $response.totalCount }

            foreach ($r in $response.results) { $this.ResultsList.Add([Result]::new($r)) }

            Write-Verbose "$($this.Limit) Results Retrieved with Offset: $($this.Offset)"
            $this.Offset += $this.Limit
            
        } while ($this.Offset -lt $this.TotalCount)
    }

    #endregion
    #------------------------------------------------------------------------------------------------------------------------------------------------
}

#endregion
#----------------------------------------------------------------------------------------------------------------------------------------------------
