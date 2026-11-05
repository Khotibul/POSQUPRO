using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using Posqupro.Desktop.Models;
using Posqupro.Desktop.ViewModels;

namespace Posqupro.Desktop.Views.Dialogs;

/// <summary>Payment form — separated from the cart so the POS panel stays clean.</summary>
public partial class PaymentWindow : Window
{
    private readonly PosViewModel _pos;
    private bool _confirming;

    public PaymentWindow(PosViewModel pos)
    {
        InitializeComponent();
        _pos = pos;
        Owner = Application.Current.MainWindow;

        SubtotalText.Text = $"Rp {pos.Subtotal:N0}";
        DiscountText.Text = pos.DiscountValue > 0 ? $"-Rp {pos.DiscountValue:N0}" : "Rp 0";
        TaxText.Text = $"Rp {pos.TaxAmount:N0}";
        TotalText.Text = $"Rp {pos.GrandTotal:N0}";
        ChangeText.Text = $"Rp {pos.Change:N0}";

        CustomerBox.ItemsSource = pos.Customers;
        CustomerBox.SelectedItem = pos.SelectedCustomer;
        CustomerBox.DisplayMemberPath = "Name";

        MethodBox.ItemsSource = pos.PaymentMethods;
        MethodBox.SelectedItem = pos.SelectedPaymentMethod;
        MethodBox.DisplayMemberPath = "Label";

        DiscountBox.Text = pos.DiscountText;
        DiscountTypeBox.SelectedIndex = pos.DiscountTypeIndex;
        NotesBox.Text = pos.Notes;
        PaidBox.Text = pos.PaidText;
        AutoPrintCheck.IsChecked = pos.AutoPrint;
        InvoiceHint.Text = $"Total tagihan · {pos.CartSummary}";
        ItemCountText.Text = $"{pos.ItemCount} item";

        foreach (var option in pos.QuickCashOptions)
        {
            var button = new Button
            {
                Content = option.Label,
                Margin = new Thickness(0, 0, 6, 6),
                Padding = new Thickness(10, 5, 10, 5),
                FontSize = 11,
                Tag = option.Amount,
            };
            button.SetResourceReference(StyleProperty, "GhostButton");
            button.Click += OnQuickCash;
            QuickCashList.Items.Add(button);
        }

        PaidBox.TextChanged += (_, _) => RecalculateChange();
        Loaded += (_, _) =>
        {
            PaidBox.Focus();
            PaidBox.SelectAll();
        };
        PreviewKeyDown += (_, e) =>
        {
            if (e.Key == Key.Space && IsFocusedElement(PaidBox))
            {
                PaidBox.Text = pos.GrandTotal.ToString("0.##");
                e.Handled = true;
            }
        };
    }

    private static bool IsFocusedElement(UIElement element) =>
        ReferenceEquals(Keyboard.FocusedElement, element) ||
        ReferenceEquals(FocusManager.GetFocusedElement(element), element);

    private void OnQuickCash(object sender, RoutedEventArgs e)
    {
        if (sender is not FrameworkElement { Tag: decimal amount })
        {
            return;
        }

        PaidBox.Text = amount < 0 ? _pos.GrandTotal.ToString("0.##") : amount.ToString("0.##");
        PaidBox.Focus();
        PaidBox.SelectAll();
    }

    private void RecalculateChange()
    {
        var paid = decimal.TryParse(PaidBox.Text, out var value) ? value : 0;
        var change = Math.Max(0, paid - _pos.GrandTotal);
        ChangeText.Text = $"Rp {change:N0}";
    }

    private void OnConfirm(object sender, RoutedEventArgs e)
    {
        if (_confirming)
        {
            return;
        }

        // push form → view model
        _pos.SelectedCustomer = CustomerBox.SelectedItem as Customer;
        _pos.SelectedPaymentMethod = MethodBox.SelectedItem as PaymentMethod;
        _pos.DiscountText = string.IsNullOrWhiteSpace(DiscountBox.Text) ? "0" : DiscountBox.Text.Trim();
        _pos.DiscountTypeIndex = DiscountTypeBox.SelectedIndex;
        _pos.Notes = NotesBox.Text;
        _pos.PaidText = string.IsNullOrWhiteSpace(PaidBox.Text) ? _pos.GrandTotal.ToString("0.##") : PaidBox.Text.Trim();
        _pos.AutoPrint = AutoPrintCheck.IsChecked == true;

        var paid = decimal.TryParse(_pos.PaidText, out var paidValue) ? paidValue : 0;
        if (!_pos.IsCreditSale && paid < _pos.GrandTotal)
        {
            ErrorText.Text = $"Jumlah bayar kurang dari total (Rp {_pos.GrandTotal:N0}).";
            ErrorText.Visibility = Visibility.Visible;
            PaidBox.Focus();
            PaidBox.SelectAll();
            return;
        }

        ErrorText.Visibility = Visibility.Collapsed;
        _confirming = true;
        IsEnabled = false;

        _ = ConfirmAsync();
    }

    private async Task ConfirmAsync()
    {
        try
        {
            await _pos.CheckoutFromDialogAsync();
            DialogResult = true;
        }
        catch (Exception exception)
        {
            ErrorText.Text = exception.Message;
            ErrorText.Visibility = Visibility.Visible;
            IsEnabled = true;
            _confirming = false;
        }
    }

    private void OnCancel(object sender, RoutedEventArgs e)
    {
        DialogResult = false;
    }
}
