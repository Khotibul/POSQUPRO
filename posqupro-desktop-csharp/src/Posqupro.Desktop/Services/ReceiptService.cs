using System.IO;
using System.Printing;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Posqupro.Desktop.Models;

namespace Posqupro.Desktop.Services;

public sealed class ReceiptService(AppSettingsStore settings)
{
    private Dictionary<string, string>? _cache;

    private async Task<Dictionary<string, string>> MapAsync()
    {
        return _cache ??= await AppServices.Queries.GetSettingMapAsync();
    }

    public async Task<string> BuildTextAsync(SaleResult sale, int paperWidth = 0)
    {
        var map = await MapAsync();
        var width = ResolveWidth(map, paperWidth);
        var align = map.GetValueOrDefault("printer.alignment", "left");
        var builder = new StringBuilder();
        var name = map.GetValueOrDefault("store.name", "TOKO POSQU PRO");
        var address = map.GetValueOrDefault("store.address", "");
        var phone = map.GetValueOrDefault("store.phone", "");
        var header = map.GetValueOrDefault("receipt.header", "Terima Kasih Telah Berbelanja");
        var footer = map.GetValueOrDefault("receipt.footer", "Barang yang sudah dibeli tidak dapat ditukar/dikembalikan");

        builder.AppendLine(Align(name, width, align));
        if (!string.IsNullOrWhiteSpace(address))
        {
            builder.AppendLine(Align(address, width, align));
        }

        if (!string.IsNullOrWhiteSpace(phone))
        {
            builder.AppendLine(Align($"Telp {phone}", width, align));
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
        builder.AppendLine(Align(header, width, align));
        if (!string.IsNullOrWhiteSpace(footer))
        {
            builder.AppendLine(Align(footer, width, align));
        }

        return builder.ToString();
    }

    public async Task PrintAsync(SaleResult sale, bool showDialog = true)
    {
        var map = await MapAsync();
        var text = await BuildTextAsync(sale);
        var fontSize = ResolveFontSize(map);
        var fontFamilyName = map.GetValueOrDefault("printer.font.family", "");
        if (string.IsNullOrWhiteSpace(fontFamilyName))
        {
            fontFamilyName = "Consolas";
        }

        var spacing = ParseInt(map, "printer.spacing.line", 100, 50, 200);
        var marginTop = ParseInt(map, "printer.margin.top", 0, 0, 50);
        var marginBottom = ParseInt(map, "printer.margin.bottom", 0, 0, 50);
        var marginLeft = ParseInt(map, "printer.margin.left", 0, 0, 50);
        var align = map.GetValueOrDefault("printer.alignment", "left");
        var printerName = map.GetValueOrDefault("printer.name", "");
        var logoPath = map.GetValueOrDefault("receipt.logo.path", "");

        var document = new FlowDocument
        {
            FontFamily = new FontFamily(fontFamilyName),
            FontSize = fontSize,
            PagePadding = new Thickness(marginLeft, marginTop, marginLeft, marginBottom),
            ColumnWidth = double.PositiveInfinity,
        };

        var paragraph = new Paragraph { Margin = new Thickness(0) };
        paragraph.TextAlignment = align switch
        {
            "center" => TextAlignment.Center,
            "right" => TextAlignment.Right,
            _ => TextAlignment.Left,
        };

        if (!string.IsNullOrWhiteSpace(logoPath) && File.Exists(logoPath))
        {
            try
            {
                var image = new Image
                {
                    Source = new BitmapImage(new Uri(Path.GetFullPath(logoPath))),
                    Width = 120,
                    Stretch = Stretch.Uniform,
                };
                paragraph.Inlines.Add(new InlineUIContainer(image));
            }
            catch
            {
                // logo optional — skip on failure
            }
        }

        paragraph.Inlines.Add(new Run(text));
        paragraph.LineHeight = fontSize * spacing / 100.0 * 1.2;
        paragraph.LineStackingStrategy = LineStackingStrategy.BlockLineHeight;
        document.Blocks.Add(paragraph);

        var queue = FindPrintQueue(printerName);
        var dialog = new PrintDialog();
        if (queue is not null)
        {
            dialog.PrintQueue = queue;
        }

        if (!showDialog)
        {
            document.PageWidth = dialog.PrintableAreaWidth;
            dialog.PrintDocument(((IDocumentPaginatorSource)document).DocumentPaginator, $"Struk {sale.InvoiceNumber}");
            return;
        }

        if (dialog.ShowDialog() == true)
        {
            document.PageWidth = dialog.PrintableAreaWidth;
            dialog.PrintDocument(((IDocumentPaginatorSource)document).DocumentPaginator, $"Struk {sale.InvoiceNumber}");
        }
    }

    private static PrintQueue? FindPrintQueue(string printerName)
    {
        if (string.IsNullOrWhiteSpace(printerName) ||
            printerName.Equals("auto", StringComparison.OrdinalIgnoreCase) ||
            printerName.Equals("Deteksi otomatis...", StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        try
        {
            using var server = new LocalPrintServer();
            foreach (var queue in server.GetPrintQueues())
            {
                if (string.Equals(queue.Name, printerName, StringComparison.OrdinalIgnoreCase) ||
                    queue.Name.Contains(printerName, StringComparison.OrdinalIgnoreCase))
                {
                    return queue;
                }
            }
        }
        catch
        {
            // fall back to system default
        }

        return null;
    }

    private static int ResolveWidth(Dictionary<string, string> map, int paperWidth)
    {
        var configured = paperWidth > 0 ? paperWidth : ParseInt(map, "printer.paper.width", 48, 32, 72);
        // legacy mm values (58/80) map to classic column counts
        return configured switch
        {
            58 => 32,
            80 => 42,
            < 32 => 32,
            > 72 => 72,
            _ => configured,
        };
    }

    private static double ResolveFontSize(Dictionary<string, string> map)
    {
        var raw = map.GetValueOrDefault("printer.font.size", "8");
        if (string.IsNullOrWhiteSpace(raw) || raw.Equals("Auto", StringComparison.OrdinalIgnoreCase) || raw == "0")
        {
            return 8;
        }

        if (double.TryParse(raw, out var size) && size >= 6 && size <= 24)
        {
            return size;
        }

        return 8;
    }

    private static int ParseInt(Dictionary<string, string> map, string key, int fallback, int min, int max)
    {
        if (int.TryParse(map.GetValueOrDefault(key), out var value))
        {
            return Math.Clamp(value, min, max);
        }

        return fallback;
    }

    private static string Align(string value, int width, string align)
    {
        if (value.Length >= width)
        {
            return value;
        }

        return align switch
        {
            "center" => new string(' ', (width - value.Length) / 2) + value,
            "right" => new string(' ', width - value.Length) + value,
            _ => value,
        };
    }

    private static string Money(decimal value) => value.ToString("#,##0");

    private static string Pair(string label, string value, int width)
    {
        var spaces = Math.Max(1, width - label.Length - value.Length);
        return label + new string(' ', spaces) + value;
    }
}
