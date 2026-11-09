using System.Globalization;
using System.Windows;
using Posqupro.Desktop.ViewModels;

namespace Posqupro.Desktop.Views.Dialogs;

public sealed record UpdatePriceResult(
    bool UpdateCost,
    decimal Cost,
    bool UpdateRetail,
    decimal Retail,
    bool UpdateWholesale,
    decimal Wholesale,
    int MinWholesale);

/// <summary>Dialog "Update Harga Produk" ala Java desktop: pilih field mana yang ditulis ke produk master.</summary>
public partial class UpdatePriceWindow : Window
{
    private UpdatePriceWindow(
        Window owner,
        string productName,
        decimal retail,
        decimal cost,
        decimal wholesale,
        int minWholesale)
    {
        InitializeComponent();
        Owner = owner;
        MessageText.Text = productName;
        CostBox.Text = cost.ToString(CultureInfo.InvariantCulture);
        RetailBox.Text = retail.ToString(CultureInfo.InvariantCulture);
        WholesaleBox.Text = wholesale.ToString(CultureInfo.InvariantCulture);
        MinWholesaleBox.Text = minWholesale > 0
            ? minWholesale.ToString(CultureInfo.InvariantCulture)
            : "";
    }

    /// <summary>Opens the dialog and returns the checked price updates, or null when cancelled.</summary>
    public static UpdatePriceResult? Ask(
        Window? owner,
        string productName,
        decimal retail,
        decimal cost,
        decimal wholesale,
        int minWholesale)
    {
        var window = new UpdatePriceWindow(
            owner ?? Application.Current.MainWindow!,
            productName,
            retail,
            cost,
            wholesale,
            minWholesale);
        return window.ShowDialog() == true ? window._result : null;
    }

    private UpdatePriceResult? _result;

    private void OnSectionChanged(object sender, RoutedEventArgs e)
    {
        CostBox.IsEnabled = CostCheck.IsChecked == true;
        WholesaleBox.IsEnabled = WholesaleCheck.IsChecked == true;
        MinWholesaleBox.IsEnabled = WholesaleCheck.IsChecked == true;
        MinWholesaleLabel.IsEnabled = WholesaleCheck.IsChecked == true;
    }

    private void OnConfirm(object sender, RoutedEventArgs e)
    {
        var updateCost = CostCheck.IsChecked == true;
        var updateRetail = RetailCheck.IsChecked == true;
        var updateWholesale = WholesaleCheck.IsChecked == true;

        if (!updateCost && !updateRetail && !updateWholesale)
        {
            Ui.Error("Centang minimal satu harga untuk diupdate.");
            return;
        }

        decimal.TryParse(CostBox.Text, NumberStyles.Number, CultureInfo.InvariantCulture, out var cost);
        decimal.TryParse(RetailBox.Text, NumberStyles.Number, CultureInfo.InvariantCulture, out var retail);
        decimal.TryParse(WholesaleBox.Text, NumberStyles.Number, CultureInfo.InvariantCulture, out var wholesale);
        int.TryParse(MinWholesaleBox.Text, NumberStyles.Integer, CultureInfo.InvariantCulture, out var minWholesale);

        if (updateCost && cost <= 0)
        {
            Ui.Error("Harga modal harus lebih dari 0.");
            return;
        }

        if (updateRetail && retail <= 0)
        {
            Ui.Error("Harga ecer harus lebih dari 0.");
            return;
        }

        if (updateWholesale && wholesale <= 0)
        {
            Ui.Error("Harga grosir harus lebih dari 0.");
            return;
        }

        _result = new UpdatePriceResult(
            updateCost,
            cost,
            updateRetail,
            retail,
            updateWholesale,
            wholesale,
            updateWholesale ? Math.Max(0, minWholesale) : 0);
        DialogResult = true;
    }

    private void OnCancel(object sender, RoutedEventArgs e)
    {
        DialogResult = false;
    }
}
