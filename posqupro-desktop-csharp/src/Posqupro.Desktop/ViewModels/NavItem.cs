namespace Posqupro.Desktop.ViewModels;

public sealed class NavItem
{
    public required string Key { get; init; }
    public required string Label { get; init; }
    public string Glyph { get; init; } = "";
    public string Shortcut { get; init; } = "";
    public string Section { get; init; } = "";
    public string[] Roles { get; init; } = [];
    public bool IsEnabled { get; set; } = true;
    public string Tooltip => string.IsNullOrWhiteSpace(Shortcut) ? Label : $"{Label}  ({Shortcut})";
}
