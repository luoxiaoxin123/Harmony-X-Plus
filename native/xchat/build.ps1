param(
  [string]$SdkNative = 'D:\DevEco Studio\sdk\default\openharmony\native',
  [string]$DownloadProxy = '',
  [ValidateSet('arm64-v8a', 'x86_64')]
  [string[]]$Abi = @('arm64-v8a', 'x86_64')
)
$ErrorActionPreference = 'Stop'
$dmWorkspace = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$dmReferences = Join-Path $dmWorkspace '.codex/dm-reference'
New-Item -ItemType Directory -Path $dmReferences -Force | Out-Null

function Get-ChatDependency {
  param([string]$Name, [string]$Url, [string]$Commit, [string[]]$SparsePaths)
  $dmCheckout = [System.IO.Path]::GetFullPath((Join-Path $dmReferences $Name))
  if (!$dmCheckout.StartsWith($dmReferences + [System.IO.Path]::DirectorySeparatorChar)) {
    throw 'Dependency path must stay in the task reference directory.'
  }
  $dmGitArgs = @()
  if ($DownloadProxy) { $dmGitArgs += @('-c', "http.proxy=$DownloadProxy") }
  if (!(Test-Path -LiteralPath (Join-Path $dmCheckout '.git'))) {
    & git @dmGitArgs clone --filter=blob:none --no-checkout $Url $dmCheckout
    if ($LASTEXITCODE) { throw "Failed to fetch $Name" }
  }
  & git @dmGitArgs -C $dmCheckout sparse-checkout set @SparsePaths
  & git @dmGitArgs -C $dmCheckout checkout --detach $Commit
  if ($LASTEXITCODE) { throw "Failed to select pinned $Name commit" }
  $dmHead = & git -C $dmCheckout rev-parse HEAD
  if ($dmHead -ne $Commit) { throw "Unexpected $Name commit" }
}

Get-ChatDependency 'chat-xdk-source' 'https://github.com/xdevplatform/chat-xdk.git' 'd3fff23efae34eb375de5ac8da11845076f39c53' @('crates','tests','docs')

$dmChatSdk = Join-Path $dmReferences 'chat-xdk-source'
$dmSdkPatch = Join-Path $PSScriptRoot 'patches/harmonyx-sdk.patch'
$dmApplyErrorPreference = $ErrorActionPreference
try {
  $ErrorActionPreference = 'Continue'
  & git -C $dmChatSdk apply --reverse --check $dmSdkPatch 2>$null
  $dmPatchApplied = $LASTEXITCODE -eq 0
} finally { $ErrorActionPreference = $dmApplyErrorPreference }
if (!$dmPatchApplied) {
  & git -C $dmChatSdk apply $dmSdkPatch
  if ($LASTEXITCODE) { throw 'Cannot apply Harmony X compatibility patch to the pinned SDK.' }
}

Get-ChatDependency 'juicebox-sdk' 'https://github.com/juicebox-systems/juicebox-sdk.git' '2e0f544e3fd0bd0997a034f73c8efb6fade3690c' @('rust')
Get-ChatDependency 'thrift' 'https://github.com/apache/thrift.git' 'deb36fa409849de45973b04ffc3ce49d277ca90a' @('lib/rs')

if ($DownloadProxy) { $env:HTTPS_PROXY = $DownloadProxy; $env:HTTP_PROXY = $DownloadProxy }
& (Join-Path $PSScriptRoot 'build-local.ps1') -SdkNative $SdkNative -Abi $Abi
