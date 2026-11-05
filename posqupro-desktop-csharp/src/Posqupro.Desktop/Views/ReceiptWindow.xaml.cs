using System.Windows;
using Posqupro.Desktop.Services;

namespace Posqupro.Desktop.Views;

/// <summary>Receipt preview dialog (text-based thermal receipt).</summary>
public partial class ReceiptWindow : Window
{
    private readonly SaleResult _sale;
    private readonly string _text;

    public ReceiptWindow(SaleResult sale, string text)
    {
        InitializeComponent();
        _sale = sale;
        _text = text;
        InvoiceText.Text = sale.InvoiceNumber;
        MetaText.Text = $"{sale.CreatedAt:dd MMM yyyy HH:mm} · {sale.PaymentMethod} · Rp {sale.Total:N0}";
        ReceiptText.Text = text;
    }

    private async void OnPrint(object sender, RoutedEventArgs e)
    {
        try
        {
            await new ReceiptService(AppServices.Settings).PrintAsync(_sale);
            MessageBox.Show("Perintah cetak dikirim.", "POSQUPRO", MessageBoxButton.OK, MessageBoxImage.Information);
        }
        catch (Exception exception)
        {
            MessageBox.Show(exception.Message, "POSQUPRO", MessageBoxButton.OK, MessageBoxImage.Warning);
        }
    }

    private void OnClose(object sender, RoutedEventArgs e) => Close();
}
