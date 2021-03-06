#!powershell

# Copyright: (c) 2014, Trond Hindenes <trond@hindenes.com>
# Copyright: (c) 2017, Dag Wieers <dag@wieers.com>
# Copyright: (c) 2018, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.ArgvParser
#Requires -Module Ansible.ModuleUtils.CommandUtil
#AnsibleRequires -CSharpUtil Ansible.Basic

# As of chocolatey 0.9.10, non-zero success exit codes can be returned
# See https://github.com/chocolatey/choco/issues/512#issuecomment-214284461
$successexitcodes = (0, 1605, 1614, 1641, 3010)

$spec = @{
    options = @{
        allow_empty_checksums = @{ type = "bool"; default = $false }
        allow_multiple = @{ type = "bool"; default = $false }
        allow_prerelease = @{ type = "bool"; default = $false }
        architecture = @{ type = "str"; default = "default"; choices = "default", "x86" }
        install_args = @{ type = "str" }
        ignore_checksums = @{ type = "bool"; default = $false }
        ignore_dependencies = @{ type = "bool"; default = $false }
        force = @{ type = "bool"; default = $false }
        name = @{ type = "list"; elements = "str"; required = $true }
        package_params = @{ type = "str"; aliases = "params" }
        proxy_url = @{ type = "str" }
        proxy_username = @{ type = "str" }
        proxy_password = @{ type = "str"; no_log = $true }
        skip_scripts = @{  type = "bool"; default = $false }
        source = @{ type = "str" }
        source_username = @{ type = "str" }
        source_password = @{ type = "str"; no_log = $true }
        state = @{ type = "str"; default = "present"; choices = "absent", "downgrade", "latest", "present", "reinstalled" }
        timeout = @{ type = "int"; default = 2700; aliases = "execution_timeout" }
        validate_certs = @{ type = "bool"; default = $false }
        version = @{ type = "str" }
    }
    supports_check_mode = $true
}
$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$allow_empty_checksums = $module.Params.allow_empty_checksums
$allow_multiple = $module.Params.allow_multiple
$allow_prerelease = $module.Params.allow_prerelease
$architecture = $module.Params.architecture
$install_args = $module.Params.install_args
$ignore_checksums = $module.Params.ignore_checksums
$ignore_dependencies = $module.Params.ignore_dependencies
$force = $module.Params.force
$name = $module.Params.name
$package_params = $module.Params.package_params
$proxy_url = $module.Params.proxy_url
$proxy_username = $module.Params.proxy_username
$proxy_password = $module.Params.proxy_password
$skip_scripts = $module.Params.skip_scripts
$source = $module.Params.source
$source_username = $module.Params.source_username
$source_password = $module.Params.source_password
$state = $module.Params.state
$timeout = $module.Params.timeout
$validate_certs = $module.Params.validate_certs
$version = $module.Params.version

$module.Result.rc = 0

if (-not $validate_certs) {
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
}

Function Get-CommonChocolateyArguments {
    # uses global vars like check_mode and verbosity to control the common args
    # run with Chocolatey
    $arguments = [System.Collections.ArrayList]@("--yes", "--no-progress")
    # global vars that control the arguments
    if ($module.CheckMode) {
        $arguments.Add("--what-if") > $null
    }
    if ($module.Verbosity -gt 4) {
        $arguments.Add("--debug") > $null
        $arguments.Add("--verbose") > $null
    } elseif ($module.Verbosity -gt 3) {
        $arguments.Add("--verbose") > $null
    } else {
        $arguments.Add("--limit-output") > $null
    }

    return ,$arguments
}

Function Get-InstallChocolateyArguments {
    param(
        [bool]$allow_downgrade,
        [bool]$allow_empty_checksums,
        [bool]$allow_multiple,
        [bool]$allow_prerelease,
        [String]$architecture,
        [bool]$force,
        [bool]$ignore_dependencies,
        [String]$install_args,
        [String]$package_params,
        [String]$proxy_url,
        [String]$proxy_username,
        [String]$proxy_password,
        [bool]$skip_scripts,
        [String]$source,
        [String]$source_usename,
        [String]$source_password,
        [int]$timeout,
        [String]$version
    )
    # returns an ArrayList of common arguments for install/updated a Chocolatey
    # package
    $arguments = [System.Collections.ArrayList]@("--fail-on-unfound")
    $common_args = Get-CommonChocolateyArguments
    $arguments.AddRange($common_args)

    if ($allow_downgrade) {
        $arguments.Add("--allow-downgrade") > $null
    }
    if ($allow_empty_checksums) {
        $arguments.Add("--allow-empty-checksums") > $null
    }
    if ($allow_multiple) {
        $arguments.Add("--allow-multiple") > $null
    }
    if ($allow_prerelease) {
        $arguments.Add("--prerelease") > $null
    }
    if ($architecture -eq "x86") {
        $arguments.Add("--x86") > $null
    }
    if ($force) {
        $arguments.Add("--force") > $null
    }
    if ($ignore_checksums) {
        $arguments.Add("--ignore-checksums") > $null
    }
    if ($ignore_dependencies) {
        $arguments.Add("--ignore-dependencies") > $null
    }
    if ($install_args) {
        $arguments.Add("--install-arguments") > $null
        $arguments.add($install_args) > $null
    }
    if ($package_params) {
        $arguments.Add("--package-parameters") > $null
        $arguments.Add($package_params) > $null
    }
    if ($proxy_url) {
        $arguments.Add("--proxy") > $null
        $arguments.Add($proxy_url) > $null
    }
    if ($proxy_username) {
        $arguments.Add("--proxy-user") > $null
        $arguments.Add($proxy_username) > $null
    }
    if ($proxy_password) {
        $arguments.Add("--proxy-password") > $null
        $arguments.Add($proxy_password) > $null
    }
    if ($skip_scripts) {
        $arguments.Add("--skip-scripts") > $null
    }
    if ($source) {
        $arguments.Add("--source") > $null
        $arguments.Add($source) > $null
    }
    if ($source_username) {
        $arguments.Add("--user") > $null
        $arguments.Add($source_username) > $null
        $arguments.Add("--password") > $null
        $arguments.Add($source_password) > $null
    }
    if ($null -ne $timeout) {
        $arguments.Add("--timeout") > $null
        $arguments.Add($timeout) > $null
    }
    if ($version) {
        $arguments.Add("--version") > $null
        $arguments.Add($version) > $null
    }

    return ,$arguments
}

Function Install-Chocolatey {
    param(
        [String]$proxy_url,
        [String]$proxy_username,
        [String]$proxy_password,
        [String]$source,
        [String]$source_username,
        [String]$source_password
    )

    $choco_app = Get-Command -Name choco.exe -CommandType Application -ErrorAction SilentlyContinue
    if ($null -eq $choco_app) {
        # We need to install chocolatey
        # Enable TLS1.1/TLS1.2 if they're available but disabled (eg. .NET 4.5)
        $security_protocols = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::SystemDefault
        if ([Net.SecurityProtocolType].GetMember("Tls11").Count -gt 0) {
            $security_protocols = $security_protcols -bor [Net.SecurityProtocolType]::Tls11
        }
        if ([Net.SecurityProtocolType].GetMember("Tls12").Count -gt 0) {
            $security_protocols = $security_protcols -bor [Net.SecurityProtocolType]::Tls12
        }
        [Net.ServicePointManager]::SecurityProtocol = $security_protocols

        $client = New-Object -TypeName System.Net.WebClient
        $environment = @{}
        if ($proxy_url) {
            # the env values are used in the install.ps1 script when getting
            # external dependencies
            $environment.chocolateyProxyLocation = $proxy_url
            $web_proxy = New-Object -TypeName System.Net.WebProxy -ArgumentList $proxy_url, $true
            $client.Proxy = $web_proxy
            if ($proxy_username -and $proxy_password) {
                $environment.chocolateyProxyUser = $proxy_username
                $environment.chocolateyProxyPassword = $proxy_password
                $sec_proxy_password = ConvertTo-SecureString -String $proxy_password -AsPlainText -Force
                $web_proxy.Credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $proxy_username, $sec_proxy_password
            }
        }

        if ($source) {
            # check if the URL already contains the path to PS script
            if ($source.EndsWith(".ps1")) {
                $script_url = $source
            } else {
                # chocolatey server automatically serves a script at
                # http://host/install.ps1, we rely on this behaviour when a
                # user specifies the choco source URL. If a custom URL or file
                # path is desired, they should use win_get_url/win_shell
                # manually
                # we need to strip the path off the URL and append install.ps1
                $uri_info = [System.Uri]$source
                $script_url = "$($uri_info.Scheme)://$($uri_info.Authority)/install.ps1"
            }
            if ($source_username) {
                # while the choco-server does not require creds on install.ps1,
                # Net.WebClient will only send the credentials if the initial
                # req fails so we will add the creds in case the source URL
                # is not choco-server and requires authentication
                $sec_source_password = ConvertTo-SecureString -String $source_password -AsPlainText -Force
                $client.Credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $source_username, $sec_source_password
            }
        } else {
            $script_url = "https://chocolatey.org/install.ps1"
        }

        try {
            $install_script = $client.DownloadString($script_url)
        } catch {
            $module.FailJson("Failed to download Chocolatey script from '$script_url'; $($_.Exception.Message)", $_)
        }
        if (-not $module.CheckMode) {
            $res = Run-Command -command "powershell.exe -" -stdin $install_script -environment $environment
            if ($res.rc -ne 0) {
                $module.Result.rc = $res.rc
                $module.Result.stdout = $res.stdout
                $module.Result.stderr = $res.stderr
                $module.FailJson("Chocolatey bootstrap installation failed.")
            }
            $module.Warn("Chocolatey was missing from this system, so it was installed during this task run.")
        }
        $module.Result.changed = $true

        # locate the newly installed choco.exe
        $choco_app = Get-Command -Name choco.exe -CommandType Application -ErrorAction SilentlyContinue
        if ($null -eq $choco_app) {
            $choco_path = $env:ChocolateyInstall
            if ($null -ne $choco_path) {
                $choco_path = "$choco_path\bin\choco.exe"
            } else {
                $choco_path = "$env:SYSTEMDRIVE\ProgramData\Chocolatey\bin\choco.exe"
            }

            $choco_app = Get-Command -Name $choco_path -CommandType Application -ErrorAction SilentlyContinue
        }
    }
    if ($module.CheckMode -and $null -eq $choco_app) {
        $module.Result.skipped = $true
        $module.Result.msg = "Skipped check mode run on win_chocolatey as choco.exe cannot be found on the system"
        $module.ExitJson()
    }

    if (-not (Test-Path -Path $choco_app.Path)) {
        $module.FailJson("Failed to find choco.exe, make sure it is added to the PATH or the env var 'ChocolateyInstall' is set")
    }

    $actual_version = (Get-ChocolateyPackageVersion -choco_path $choco_app.Path -name chocolatey)[0]
    if ([Version]$actual_version -lt [Version]"0.10.5") {
        if ($module.CheckMode) {
            $module.Result.skipped = $true
            $module.Result.msg = "Skipped check mode run on win_chocolatey as choco.exe is too old, a real run would have upgraded the executable. Actual: '$actual_version', Minimum Version: '0.10.5'"
            $module.ExitJson()
        }
        $module.Warn("Chocolatey was older than v0.10.5 so it was upgraded during this task run.")
        Update-ChocolateyPackage -choco_path $choco_app.Path -packages @("chocolatey") `
            -proxy_url $proxy_url -proxy_username $proxy_username `
            -proxy_password $proxy_password -source $source `
            -source_username $source_username -source_password $source_password
    }

    return $choco_app.Path
}

Function Get-ChocolateyPackageVersion {
    param(
        [Parameter(Mandatory=$true)][String]$choco_path,
        [Parameter(Mandatory=$true)][String]$name
    )

    $command = Argv-ToString -arguments @($choco_path, "list", "--local-only", "--exact", "--limit-output", "--all-versions", $name)
    $res = Run-Command -command $command
    if ($res.rc -ne 0) {
        $module.Result.command = $command
        $module.Result.rc = $res.rc
        $module.Result.stdout = $res.stdout
        $module.Result.stderr = $res.stderr
        $module.FailJson("Error checking installation status for the package '$name'")
    }
    $stdout = $res.stdout.Trim()
    $versions = $null
    if ($stdout) {
        # if a match occurs it is in the format of "package|version" we split
        # by the last | to get the version in case package contains a pipe char
        $versions = @($stdout.Split("`r`n", [System.StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object { $_.Substring($_.LastIndexOf("|") + 1) })
    }

    return ,$versions
}

Function Update-ChocolateyPackage {
    param(
        [Parameter(Mandatory=$true)][String]$choco_path,
        [Parameter(Mandatory=$true)][String[]]$packages,
        [bool]$allow_downgrade,
        [bool]$allow_empty_checksums,
        [bool]$allow_multiple,
        [bool]$allow_prerelease,
        [String]$architecture,
        [bool]$force,
        [bool]$ignore_checksums,
        [bool]$ignore_dependencies,
        [String]$install_args,
        [String]$package_params,
        [String]$proxy_url,
        [String]$proxy_username,
        [String]$proxy_password,
        [bool]$skip_scripts,
        [String]$source,
        [String]$source_username,
        [String]$source_password,
        [int]$timeout,
        [String]$version
    )

    $arguments = [System.Collections.ArrayList]@($choco_path, "upgrade")
    $arguments.AddRange($packages)

    $common_params = @{
        allow_downgrade = $allow_downgrade
        allow_empty_checksums = $allow_empty_checksums
        allow_multiple = $allow_multiple
        allow_prerelease = $allow_prerelease
        architecture = $architecture
        force = $force
        ignore_checksums = $ignore_checksums
        ignore_dependencies = $ignore_dependencies
        install_args = $install_args
        package_params = $package_params
        proxy_url = $proxy_url
        proxy_username = $proxy_username
        proxy_password = $proxy_password
        skip_scripts = $skip_scripts
        source = $source
        source_username = $source_username
        source_password = $source_password
        timeout = $timeout
        version = $version
    }
    $common_args = Get-InstallChocolateyArguments @common_params
    $arguments.AddRange($common_args)

    $command = Argv-ToString -arguments $arguments
    $res = Run-Command -command $command
    $module.Result.rc = $res.rc
    if ($res.rc -notin $successexitcodes) {
        $module.Result.command = $command
        $module.Result.stdout = $res.stdout
        $module.Result.stderr = $res.stderr
        $module.FailJson("Error updating package(s) '$($packages -join ", ")'")
    }

    if ($module.Verbosity -gt 1) {
        $module.Result.stdout = $res.stdout
    }

    if ($res.stdout -match ' upgraded (\d+)/\d+ package') {
        if ($Matches[1] -gt 0) {
            $module.Result.changed = $true
        }
    }
    # need to set to false in case the rc is not 0 and a failure didn't actually occur
    $module.Result.failed = $false
}

Function Install-ChocolateyPackage {
    param(
        [Parameter(Mandatory=$true)][String]$choco_path,
        [Parameter(Mandatory=$true)][String[]]$packages,
        [bool]$allow_downgrade,
        [bool]$allow_empty_checksums,
        [bool]$allow_multiple,
        [bool]$allow_prerelease,
        [String]$architecture,
        [bool]$force,
        [bool]$ignore_checksums,
        [bool]$ignore_dependencies,
        [String]$install_args,
        [String]$package_params,
        [String]$proxy_url,
        [String]$proxy_username,
        [String]$proxy_password,
        [bool]$skip_scripts,
        [String]$source,
        [String]$source_username,
        [String]$source_password,
        [int]$timeout,
        [String]$version
    )

    $arguments = [System.Collections.ArrayList]@($choco_path, "install")
    $arguments.AddRange($packages)
    $common_params = @{
        allow_downgrade = $allow_downgrade
        allow_empty_checksums = $allow_empty_checksums
        allow_multiple = $allow_multiple
        allow_prerelease = $allow_prerelease
        architecture = $architecture
        force = $force
        ignore_checksums = $ignore_checksums
        ignore_dependencies = $ignore_dependencies
        install_args = $install_args
        package_params = $package_params
        proxy_url = $proxy_url
        proxy_username = $proxy_username
        proxy_password = $proxy_password
        skip_scripts = $skip_scripts
        source = $source
        source_username = $source_username
        source_password = $source_password
        timeout = $timeout
        version = $version
    }
    $common_args = Get-InstallChocolateyArguments @common_params
    $arguments.AddRange($common_args)

    $command = Argv-ToString -arguments $arguments
    $res = Run-Command -command $command
    $module.Result.rc = $res.rc
    if ($res.rc -notin $successexitcodes) {
        $module.Result.command = $command
        $module.Result.stdout = $res.stdout
        $module.Result.stderr = $res.stderr
        $module.FailJson("Error installing package(s) '$($packages -join ', ')'")
    }

    if ($module.Verbosity -gt 1) {
        $module.Result.stdout = $res.stdout
    }

    $module.Result.changed = $true
    # need to set to false in case the rc is not 0 and a failure didn't actually occur
    $module.Result.failed = $false
}

Function Uninstall-ChocolateyPackage {
    param(
        [Parameter(Mandatory=$true)][String]$choco_path,
        [Parameter(Mandatory=$true)][String[]]$packages,
        [bool]$force,
        [String]$package_params,
        [bool]$skip_scripts,
        [int]$timeout,
        [String]$version
    )

    $arguments = [System.Collections.ArrayList]@($choco_path, "uninstall")
    $arguments.AddRange($packages)
    $common_args = Get-CommonChocolateyArguments
    $arguments.AddRange($common_args)

    if ($force) {
        $arguments.Add("--force") > $null
    }
    if ($package_params) {
        $arguments.Add("--package-params") > $null
        $arguments.Add($package_params) > $null
    }
    if ($skip_scripts) {
        $arguments.Add("--skip-scripts") > $null
    }
    if ($null -ne $timeout) {
        $arguments.Add("--timeout") > $null
        $arguments.Add($timeout) > $null
    }
    if ($version) {
        # Need to set allow-multiple to make sure choco doesn't uninstall all versions
        $arguments.Add("--allow-multiple") > $null
        $arguments.Add("--version") > $null
        $arguments.Add($version) > $null
    } else {
        $arguments.Add("--all-versions") > $null
    }

    $command = Argv-ToString -arguments $arguments
    $res = Run-Command -command $command
    $module.Result.rc = $res.rc
    if ($res.rc -notin $successexitcodes) {
        $module.Result.command = $command
        $module.Result.stdout = $res.stdout
        $module.Result.stderr = $res.stderr
        $module.FailJson("Error uninstalling package(s) '$($packages -join ", ")'")
    }

    if ($module.Verbosity -gt 1) {
        $module.Result.stdout = $res.stdout
    }
    $module.Result.changed = $true
    # need to set to false in case the rc is not 0 and a failure didn't actually occur
    $module.Result.failed = $false
}

# get the full path to choco.exe, otherwise install/upgrade to at least 0.10.5
$choco_path = Install-Chocolatey -proxy_url $proxy_url -proxy_username $proxy_username `
    -proxy_password $proxy_password -source $source -source_username $source_username `
    -source_password $source_password

# get the version of all specified packages
$package_info = @{}
foreach ($package in $name) {
    # all is a special package name that means all installed packages, we set
    # a dummy version so absent, latest, and downgrade will run with all
    if ($package -eq "all") {
        if ($state -in @("present", "reinstalled")) {
            $module.FailJson("Cannot specify the package name as 'all' when state=$state")
        }
        $package_versions = @("0.0.0")
    } else {
        $package_versions = Get-ChocolateyPackageVersion -choco_path $choco_path -name $package
    }
    $package_info.$package = $package_versions
}

if ($state -in "absent", "reinstalled") {
    $installed_packages = ($package_info.GetEnumerator() | Where-Object { $null -ne $_.Value }).Key
    if ($null -ne $installed_packages) {
        Uninstall-ChocolateyPackage -choco_path $choco_path -packages $installed_packages `
            -force $force -package_params $package_params -skip_scripts $skip_scripts `
            -timeout $timeout -version $version
    }

    # ensure the package info for the uninstalled versions has been removed
    # so state=reinstall will install them in the next step
    foreach ($package in $installed_packages) {
        $package_info.$package = $null
    }
}

if ($state -in @("downgrade", "latest", "present", "reinstalled")) {
    if ($state -eq "present" -and $force) {
        # when present and force, we just run the install step with the packages specified
        $missing_packages = $name
    } else {
        # otherwise only install the packages that are not installed
        $missing_packages = [System.Collections.ArrayList]@()
        foreach ($package in $package_info.GetEnumerator()) {
            if ($null -eq $package.Value) {
                $missing_packages.Add($package.Key) > $null
            }
        }
    }

    # if version is specified and installed version does not match or not
    # allow_multiple, throw error ignore this if force is set
    if ($state -eq "present" -and $null -ne $version -and -not $force) {
        foreach ($package in $name) {
            $package_versions = [System.Collections.ArrayList]$package_info.$package
            if ($package_versions.Count -gt 0) {
                if (-not $package_versions.Contains($version) -and -not $allow_multiple) {
                    $module.FailJson("Chocolatey package '$package' is already installed with version(s) '$($package_versions -join "', '")' but was expecting '$version'. Either change the expected version, set state=latest, set allow_multiple=yes, or set force=yes to continue")
                } elseif ($version -notin $package_versions -and $allow_multiple) {
                    # add the package back into the list of missing packages if installing multiple
                    $missing_packages.Add($package) > $null
                }
            }
        }
    }
    $common_args = @{
        choco_path = $choco_path
        allow_downgrade = ($state -eq "downgrade")
        allow_empty_checksums = $allow_empty_checksums
        allow_multiple = $allow_multiple
        allow_prerelease = $allow_prerelease
        architecture = $architecture
        force = $force
        ignore_checksums = $ignore_checksums
        ignore_dependencies = $ignore_dependencies
        install_args = $install_args
        package_params = $package_params
        proxy_url = $proxy_url
        proxy_username = $proxy_username
        proxy_password = $proxy_password
        skip_scripts = $skip_scripts
        source = $source
        source_username = $source_username
        source_password = $source_password
        timeout = $timeout
        version = $version
    }

    if ($missing_packages) {
        Install-ChocolateyPackage -packages $missing_packages @common_args
    }

    if ($state -eq "latest" -or ($state -eq "downgrade" -and $null -ne $version)) {
        # when in a downgrade/latest situation, we want to run choco upgrade on
        # the remaining packages that were already installed, don't run this if
        # state=downgrade and a version isn't specified (this will actually
        # upgrade a package)
        $installed_packages = ($package_info.GetEnumerator() | Where-Object { $null -ne $_.Value }).Key
        if ($null -ne $installed_packages) {
            Update-ChocolateyPackage -packages $installed_packages @common_args
        }
    }
}

$module.ExitJson()

