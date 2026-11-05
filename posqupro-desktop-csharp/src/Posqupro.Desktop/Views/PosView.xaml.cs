using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using Posqupro.Desktop.Models;
using Posqupro.Desktop.ViewModels;

namespace Posqupro.Desktop.Views;

public partial class PosView : UserControl
{
    private PosViewModel? _vm;

    public PosView()
    {
        InitializeComponent();
        DataContextChanged += OnDataContextChanged;
        Loaded += async (_, _) =>
        {
            FocusBarcode();
            if (_vm is not null)
            {
                await _vm.RefreshParkedAsync();
            }
        };
        PreviewKeyDown += OnPreviewKeyDown;
    }

    private void OnDataContextChanged(object sender, DependencyPropertyChangedEventArgs e)
    {
        if (_vm is not null)
        {
            _vm.RequestFocus -= OnRequestFocus;
        }

        _vm = e.NewValue as PosViewModel;
        if (_vm is not null)
        {
            _vm.RequestFocus += OnRequestFocus;
        }
    }

    private void OnRequestFocus(PosViewModel.PosFocus focus)
    {
        Dispatcher.BeginInvoke(() =>
        {
            switch (focus)
            {
                case PosViewModel.PosFocus.Search:
                    SearchBox.Focus();
                    SearchBox.SelectAll();
                    break;
                case PosViewModel.PosFocus.Barcode:
                    BarcodeBox.Focus();
                    BarcodeBox.SelectAll();
                    break;
            }
        });
    }

    private void FocusBarcode()
    {
        Dispatcher.BeginInvoke(() =>
        {
            BarcodeBox.Focus();
            BarcodeBox.SelectAll();
        });
    }

    private void OnPreviewKeyDown(object sender, KeyEventArgs e)
    {
        if (Keyboard.Modifiers == ModifierKeys.Control && e.Key == Key.F)
        {
            SearchBox.Focus();
            SearchBox.SelectAll();
            e.Handled = true;
            return;
        }

        if (Keyboard.Modifiers == ModifierKeys.Control && e.Key == Key.B)
        {
            BarcodeBox.Focus();
            BarcodeBox.SelectAll();
            e.Handled = true;
            return;
        }

        if (Keyboard.Modifiers == ModifierKeys.Control && e.Key == Key.S)
        {
            if (_vm?.ParkCommand is ICommand park && park.CanExecute(null))
            {
                park.Execute(null);
            }

            e.Handled = true;
            return;
        }

        if (Keyboard.Modifiers == ModifierKeys.Control && e.Key == Key.Delete)
        {
            if (_vm?.ClearCartCommand is ICommand clear && clear.CanExecute(null))
            {
                clear.Execute(null);
            }

            e.Handled = true;
            return;
        }

        if (e.Key == Key.F2)
        {
            if (_vm?.CheckoutCommand is ICommand checkout && checkout.CanExecute(null))
            {
                checkout.Execute(null);
            }

            e.Handled = true;
            return;
        }
    }

    private void OnSearchKeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key != Key.Enter)
        {
            return;
        }

        e.Handled = true;
        if (_vm?.SearchEnterCommand is ICommand command && command.CanExecute(null))
        {
            command.Execute(null);
        }
    }

    private void OnBarcodeKeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key != Key.Enter)
        {
            return;
        }

        e.Handled = true;
        if (_vm?.AddByCodeCommand is ICommand command && command.CanExecute(null))
        {
            command.Execute(null);
        }
    }

    private void OnProductClick(object sender, MouseButtonEventArgs e)
    {
        if (sender is not FrameworkElement element || element.DataContext is not Product product)
        {
            return;
        }

        if (_vm?.AddToCartCommand is ICommand command && command.CanExecute(product))
        {
            command.Execute(product);
        }
    }
}
