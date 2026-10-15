# Recupere le dernier MotivPlan.ipa construit par la CI sur main et le pose dans
# Downloads\MotivPlan\MotivPlan.ipa, pret a etre importe dans iloader.
#   .\scripts\get-ipa.ps1          dernier .ipa deja construit sur main
#   .\scripts\get-ipa.ps1 -Build   lance d'abord une construction sur main et l'attend
# (Fichier volontairement sans accents : Windows PowerShell 5.1 lit les .ps1 en ANSI.)
param([switch]$Build)

$ErrorActionPreference = 'Stop'
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
$repo = 'stascenzia/motivplan'
$dest = Join-Path $HOME 'Downloads\MotivPlan'

if ($Build) {
    Write-Host 'Lancement de la CI iOS sur main...'
    gh workflow run iOS --repo $repo --ref main
    Start-Sleep 10
    $id = gh run list --repo $repo --workflow iOS --branch main --event workflow_dispatch --limit 1 --json databaseId --jq '.[0].databaseId'
    Write-Host "Construction $id en cours (20 a 40 min)..."
    gh run watch $id --repo $repo --interval 60 | Out-Null
    # Seul le job du paquet compte : un echec ailleurs (envoi des captures...) ne bloque pas le .ipa.
    $ipaJob = gh run view $id --repo $repo --json jobs --jq '.jobs[] | select(.name == \"Paquet .ipa\") | .conclusion'
    if ($ipaJob -ne 'success') { throw "Le .ipa n'a pas ete construit : https://github.com/$repo/actions/runs/$id" }
} else {
    # Derniere execution sur main dont le job du paquet a reussi.
    $id = $null
    foreach ($candidate in (gh run list --repo $repo --workflow iOS --branch main --status completed --limit 10 --json databaseId --jq '.[].databaseId')) {
        $ipaJob = gh run view $candidate --repo $repo --json jobs --jq '.jobs[] | select(.name == \"Paquet .ipa\") | .conclusion'
        if ($ipaJob -eq 'success') { $id = $candidate; break }
    }
    if (-not $id) { throw 'Aucun .ipa construit sur main. Relancer avec -Build.' }
}

$run = gh run view $id --repo $repo --json headSha,displayTitle,createdAt | ConvertFrom-Json
$latest = gh api "repos/$repo/commits/main" --jq '.sha'
if ($run.headSha -ne $latest) {
    Write-Warning 'Ce .ipa ne contient pas le dernier commit de main. Relancer avec -Build pour la toute derniere version.'
}

$tmp = Join-Path $env:TEMP "motivplan-ipa-$id"
if (-not (Test-Path (Join-Path $tmp 'MotivPlan.ipa'))) {
    gh run download $id --repo $repo -n MotivPlan-ipa -D $tmp
}
New-Item -ItemType Directory -Force $dest | Out-Null
Copy-Item -Force (Join-Path $tmp 'MotivPlan.ipa') (Join-Path $dest 'MotivPlan.ipa')

Write-Host ''
Write-Host "OK : $dest\MotivPlan.ipa"
Write-Host "Version : $($run.displayTitle) ($($run.headSha.Substring(0, 7)), $($run.createdAt))"
Write-Host 'Suite : iloader > installer le .ipa (ne pas supprimer l app avant).'
explorer.exe "/select,$dest\MotivPlan.ipa"
