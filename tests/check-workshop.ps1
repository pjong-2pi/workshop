[CmdletBinding()]
param([string]$ProjectRoot = (Join-Path $PSScriptRoot '..'))

$ErrorActionPreference = 'Stop'
try {
    $root = [System.IO.Path]::GetFullPath($ProjectRoot)
    $gitRoot = git -C $root rev-parse --show-toplevel
    if ($LASTEXITCODE -ne 0 -or [System.IO.Path]::GetFullPath($gitRoot) -ne $root.TrimEnd('\', '/')) {
        throw 'ProjectRoot must be the root of a Git working tree.'
    }
    $files = @(git -C $root -c core.quotePath=false ls-files --cached --others --exclude-standard -- '*.md' '*.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Cannot list project files.' }
    $definitions = 0
    $links = 0
    foreach ($file in $files) {
        $path = Join-Path $root $file
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue } # Deleted files are checked by Git.
        $content = Get-Content -Raw -LiteralPath $path
        if ($file -match '^\.agents/(agents/[^/]+\.md|skills/.+/SKILL\.md)$') {
            $frontmatter = [regex]::Match($content, '(?s)\A---\r?\n(.*?)\r?\n---(?:\r?\n|$)')
            if (-not $frontmatter.Success) { throw "${file}: missing frontmatter." }
            foreach ($field in @('name', 'description')) {
                $value = [regex]::Match($frontmatter.Groups[1].Value, "(?m)^${field}:[ \t]*([^\r\n]*)").Groups[1].Value.Trim().Trim([char[]]@('"', "'"))
                if (-not $value -or $value.StartsWith('#')) { throw "${file}: missing or empty $field." }
                if ($field -eq 'name' -and $value -cnotmatch '^workshop-[a-z0-9]+(?:-[a-z0-9]+)*$') {
                    throw "${file}: name must use lowercase workshop-prefixed kebab-case."
                }
                if ($field -eq 'description' -and $value -match '^[>|][-+0-9]*$') {
                    if ($frontmatter.Groups[1].Value -notmatch '(?m)^description:[^\r\n]*\r?\n[ \t]+\S') {
                        throw "${file}: empty multiline description."
                    }
                }
            }
            $definitions++
        }
        if ($file -notlike '*.md') { continue }
        # ponytail: inline Markdown links only; add reference-link parsing when those links are used.
        $linkText = [regex]::Replace($content, '(?ms)^ {0,3}(`{3,}|~{3,})[^\r\n]*\r?\n.*?^ {0,3}\1[ \t]*(?:\r?\n|$)', '')
        $linkText = [regex]::Replace($linkText, '`[^`\r\n]*`', '')
        foreach ($match in [regex]::Matches($linkText, '\]\(\s*(?:<(?<target>[^>\r\n]+)>|(?<target>[^\s)]+))(?:\s+[^)]+)?\)')) {
            $target = $match.Groups['target'].Value
            if ($target -match '^([a-z][a-z0-9+.-]*:|//)' -and $target -notmatch '^[a-z]:[\\/]') { continue }
            $target = [System.Uri]::UnescapeDataString(($target -split '[#?]', 2)[0])
            if (-not $target) { continue } # In-document anchors do not require another file.
            $targetPath = [System.IO.Path]::GetFullPath((Join-Path (Split-Path $path) $target))
            $knowledgebasePath = (Join-Path $root 'knowledgebase') + [System.IO.Path]::DirectorySeparatorChar
            if ($targetPath.StartsWith($knowledgebasePath, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
            if (-not (Test-Path -LiteralPath $targetPath)) { throw "${file}: broken local link '$target'." }
            $links++
        }
    }
    if ($definitions -eq 0) { throw 'No agent or skill definitions found.' }
    git -C $root diff --check
    if ($LASTEXITCODE -ne 0) { throw 'Working-tree whitespace check failed.' }
    git -C $root diff --cached --check
    if ($LASTEXITCODE -ne 0) { throw 'Staged whitespace check failed.' }
    $newFiles = @(git -C $root -c core.quotePath=false ls-files --others --exclude-standard -- '*.md' '*.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Cannot list new files.' }
    foreach ($file in $newFiles) {
        $whitespace = @(git -C $root -c core.autocrlf=false diff --no-index --check -- /dev/null (Join-Path $root $file) 2>&1)
        # --no-index returns 1 for a clean new file's ordinary content difference.
        if ($LASTEXITCODE -notin @(0, 1) -or $whitespace.Count) { throw "${file}: new-file whitespace check failed. $whitespace" }
    }
    "PASS: $definitions definitions, $links local file links, and tracked/new-file whitespace."
} catch {
    [Console]::Error.WriteLine("FAIL: $($_.Exception.Message)")
    exit 1
}
