# Scoop QA

This document records my learning process upon scoop.

## Usuage

### Configuration

The configuration is stored in `$HOME/.config/scoop/config.json`. You could use
several command to modify:

```bash
scoop config # get all
scoop config <name> # get
scoop config <name> <value> # set
scoop config rm <name> # remove 
```

It should be noticed that for string configuration, you should explicitly use `rm` to
remove it rather use `<name> ""` to set it as empty string, e.g. If you set **`proxy`** to
`""`, it still takes affect, also, reverse proxy, **`url_proxy`** to `""` will append a null
`/` slash to the download url, causing problem. It's really painful when you can't figure out
the problem due to the empty string, wasting whole day.

**path related**:
- `use_isolated_path`: a isolated path of env `SCOOP_PATH` to store apps, which is a single path oriented management.
- `cache_path`: cache path.

- **gh_token**: usually the daily update frequency won't reach the limit of github access.
- **virustotal_api_key**: you can register the account of it and use the api key for virus checking.

---

## Manifest

Manifest is the package info. Several fact needed to be mentioned.

First, all field describe a **static** value of a package. e.g. version, homepage etc...

Special Field:

- `architecture`: specify each field `32bit|64bit|arm64` to record variation on **above fields**.
```json
"architecture": {
	"64bit": {
		"url": "https://www.7-zip.org/a/7z2500-x64.msi",
		"hash": "b48e905ed02c530638e6173f2d743668e63561aac1914d2723fbee5690792272",
		"extract_dir": "Files\\7-Zip"
	},
	...
}
```
- `checkver`: 
	- github of `homepage/url`:
	```json
	"homepage": "https://github.com/coreybutler/nvm-windows",
	"checkver": "github"
	```
	```json
	"homepage": "http://cmder.net",
	"checkver": {
		"github": "https://github.com/cmderdev/cmder"
	}
	```
	- regex of `homepage` html element, e.g. "Version ([\\d.]+)":
	```json
	"checkver": {
		"url": "https://www.7-zip.org/download.html",
		"regex": "Download 7-Zip ([\\d.]+)"
	}
	```
	- json path of [JSONpath expression](https://goessner.net/articles/JsonPath/)
	```json
	"checkver": {
		"url": "https://mran.microsoft.com/assets/configurations/app.config.json",
		"jsonpath": "$.latestMicrosoftRVersion"
	}
	```
	- json path plus **regex** match:
	```json
	"checkver": {
		"url": "https://nwjs.io/versions.json",
		"jsonpath": "$.stable",
		"regex": "v([\\d.]+)"
	}
	```
	
However, above things are **static**, which contains no variations.
We has `autoupdate` as a variation record **above fields** except `checkver`.

It use variables substitution to achieve variations, the most important thing is `url`.

- **Version**: use `checkver` provided `version` to specify `url`.
- Captured: use captured groups to specify `url`.
- Url: use continguous field `url` to specify `hash`'s `url` field.

We first notate a variation of [`hash`](https://github.com/ScoopInstaller/Scoop/wiki/App-Manifest-Autoupdate#adding-checkver-to-a-manifest), you can specify in various ways.

I emphasize on github hash, currently, github api: [Get-Release](https://docs.github.com/en/rest/releases/releases?apiVersion=2022-11-28#get-a-release) already support a digest field.

For url `https://api.github.com/repos/OWNER/REPO/releases/RELEASE_ID`, we acquire a json reponse:

```json
assets: [
	{
		url: "..."
		digest: "sha256:..."
	}
]
```

But I didn't see that official docs mentioning this, but many package manifest use `checkver: "github"`
to **automatically** specify the hash, I guess it works so.

---

## Bucket

So how can manifest be auto-updated? It's implemented by scoop itself, but you prefer **bucket**.
[ScoopInstaller](https://github.com/ScoopInstaller) has official bucket as a bundle of manifests, 
the main point is to automatically update the manifests it concludes.

We first notate how it works, scoop use:

```ps1
# scoop/lib/autoupdate.ps1

function Invoke-AutoUpdate {
    param (
        [String]
        $AppName,
        [String]
        $Path,
        [PSObject]
        $Manifest,
        [String]
        $Version,
        [Hashtable]
        $CustomMatches
    )
	$hasChanged = Update-ManifestProperty -Manifest $Manifest -Property $updatedProperties -AppName $AppName -Version $Version -Substitutions $substitutions
}
```
Given a new version and custom matches, substitute all things based on `autoupdate` field.

```ps1
# scoop/bin/chekver.ps1

$Queue | ForEach-Object {
	# downloads based on json
	# update file(manifest)
}
```

```ps1
# scoop/bin/auto_pr.ps1

# checkver to update manifest
# automatically create pr and push with changed manifest

# Creates a new, temporary branch for each specific manifest update (e.g., manifest/myapp-1.2.3).

# Commits the updated manifest to this new branch.

# Pushes this new branch to the user's fork (the origin remote).

# Opens a pull request from this new branch on the user's fork to the $upstream branch (e.g., master or main) of the official bucket repository.
```

Now it's already handled by github bot, for many official bucket:

```ps1
# ScoopInstaller/GithubActions
# src/Variables.psm1
$BINARIES_FOLDER = Join-Path $env:SCOOP_HOME 'bin'

# src/Action/Scheduled.psm1

function Initialize-Scheduled {
	$params = @{
        'Dir'          = $MANIFESTS_LOCATION
        'Upstream'     = "${REPOSITORY}:${_BRANCH}"
        'OriginBranch' = $_BRANCH
        'Push'         = $true
        'SkipUpdated'  = ($env:SKIP_UPDATED -eq '1')
    }

	...
	& (Join-Path $BINARIES_FOLDER 'auto-pr.ps1') @params
	...
}

# src/ActionWrapper.psm1
function Invoke-Action {
    <#
    .SYNOPSIS
        Invoke specific action handler.
    #>
    switch ($EVENT_TYPE) {
        'pull_request' { Initialize-PR }
        'pull_request_target' { Initialize-PR }
        'issue_comment' { Initialize-PR }
        'schedule' { Initialize-Scheduled }
        'workflow_dispatch' { Initialize-Scheduled }
        'issues' { Initialize-Issue }
        default { Write-Log 'Not supported event type' }
    }
}
```

Github actions is designed to execute in certain event type, in which `schedule`
type is excavator.

```yaml
# ScoopInstaller/Extras
# .github/workflows/excavator.yml

on:
  workflow_dispatch:
  schedule:
    # run every 4 hours
    - cron: '20 */4 * * *'
name: Excavator
jobs:
  excavate:
    name: Excavate
    runs-on: windows-latest
    steps:
    - uses: actions/checkout@main
    - name: Excavate
      uses: ScoopInstaller/GithubActions@main
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        SKIP_UPDATED: '1'
```

We can see it call the excavator by the trigger event `schedule:...`.