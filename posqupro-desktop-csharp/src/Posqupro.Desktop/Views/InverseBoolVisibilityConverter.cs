using System.Globalization;
using System.Windows;
using System.Windows.Data;

namespace Posqupro.Desktop.Views;

/// <summary>Inverts a boolean to Visibility (true → Collapsed).</summary>
public sealed class InverseBoolVisibilityConverter : IValueConverter
{
    public static readonly InverseBoolVisibilityConverter Instance = new();

    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture) =>
        value is true ? Visibility.Collapsed : Visibility.Visible;

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture) =>
        value is Visibility.Collapsed;
}
