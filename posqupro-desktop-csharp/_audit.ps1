$root = 'F:\Website Js\POSQUPRO\POSQUPRO-Desktop-CSharp'
Get-ChildItem $root -Recurse -File | ForEach-Object {
    [PSCustomObject]@{
        Path = $_.FullName.Substring($root.Length + 1)
        KB   = [math]::Round($_.Length / 1KB, 1)
        Lines = if ($_.Extension -in '.cs','.xaml','.sln','.csproj') { (Get-Content $_.FullName | Measure-Object -Line).Lines } else { 0 }
    }
} | Sort-Object Path | Format-Table -AutoSize
