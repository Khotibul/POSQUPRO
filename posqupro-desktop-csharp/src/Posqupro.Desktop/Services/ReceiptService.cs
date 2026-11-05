using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Media;
using Posqupro.Desktop.Models;

namespace Posqupro.Desktop.Services;

public sealed class ReceiptService(AppSettingsStore settings)
{
    public async Task<string> BuildTextAsync(SaleResult sale, int paperWidth = 80)
    {
        var width = paperWidth <= 58 ? 32 : 42;
        var builder = new StringBuilder();
        var storeName = await AppServices.Queries.GetSettingMapAsync();
        var name = storeName.GetValueOrDefault("store.name", "TOKO POSQU PRO");
        var address = storeName.GetValueOrDefault("store.address", "");
        var phone = storeName.GetValueOrDefault("store.phone", "");
        var header = storeName.GetValueOrDefault("receipt.header", "Terima Kasih Telah Berbelanja");
        var footer = storeName.GetValueOrDefault("receipt.footer", "SIMPLE · SMART · SUCCESS");

        builder.AppendLine(Center(name, width));
        if (!string.IsNullOrWhiteSpace(address))
        {
            builder.AppendLine(Center(address, width));
        }

        if (!string.IsNullOrWhiteSpace(phone))
        {
            builder.AppendLine(Center($"Telp {phone}", width));
        }

        builder.AppendLine(new string('-', width));
        builder.AppendLine($"No    : {sale.InvoiceNumber}");
        builder.AppendLine($"Kasir : {settings.Value.UserName}");
        builder.AppendLine($"Waktu : {sale.CreatedAt:dd/MM/yyyy HH:mm}");
        if (!string.IsNullOrWhiteSpace(sale.CustomerName))
        {
            builder.AppendLine($"Plggn : {sale.CustomerName}");
        }

        builder.AppendLine(new string('-', width));

        foreach (var line in sale.Lines)
        {
            builder.AppendLine(line.ProductName);
            builder.AppendLine(
                $"  {line.Quantity:0.##} x {Money(line.UnitPrice)}" +
                (line.Discount > 0 ? $" - {Money(line.Discount)}" : "") +
                $" = {Money(line.Quantity * line.UnitPrice - line.Discount)}");
        }

        builder.AppendLine(new string('-', width));
        builder.AppendLine(Pair("Subtotal", Money(sale.Subtotal), width));
        if (sale.Discount > 0)
        {
            builder.AppendLine(Pair("Diskon", Money(sale.Discount), width));
        }

        if (sale.Tax > 0)
        {
            builder.AppendLine(Pair("Pajak", Money(sale.Tax), width));
        }

        builder.AppendLine(Pair("TOTAL", Money(sale.Total), width));
        builder.AppendLine(Pair($"Bayar ({sale.PaymentMethod})", Money(sale.Paid), width));
        builder.AppendLine(Pair("Kembali", Money(sale.Change), width));
        builder.AppendLine(new string('-', width));
        builder.AppendLine(Center(header, width));
        if (!string.IsNullOrWhiteSpace(footer))
        {
            builder.AppendLine(Center(footer, width));
        }

        return builder.ToString();
    }

    public async Task PrintAsync(SaleResult sale)
    {
        var text = await BuildTextAsync(sale);
        var document = new FlowDocument
        {
            FontFamily = new FontFamily("Consolas"),
            FontSize = 10,
            PagePadding = new Thickness(8),
            ColumnWidth = double.PositiveInfinity,
        };
        document.Blocks.Add(new Paragraph(new Run(text)) { Margin = new Thickness(0) });

        var dialog = new PrintDialog();
        if (dialog.ShowDialog() == true)
        {
            document.PageWidth = dialog.PrintableAreaWidth;
            dialog.PrintDocument(((IDocumentPaginatorSource)document).DocumentPaginator, $"Struk {sale.InvoiceNumber}");
        }
    }

    private static string Money(decimal value) => value.ToString("#,##0");

    private static string Center(string value, int width) =>
        value.Length >= width ? value : new string(' ', (width - value.Length) / 2) + value;

    private static string Pair(string label, string value, int width)
    {
        var spaces = Math.Max(1, width - label.Length - value.Length);
        return label + new string(' ', spaces) + value;
    }
}
