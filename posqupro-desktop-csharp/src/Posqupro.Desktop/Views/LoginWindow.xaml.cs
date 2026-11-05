using System.Windows;
using System.Windows.Input;
using Posqupro.Desktop.ViewModels;

namespace Posqupro.Desktop.Views;

public partial class LoginWindow : Window
{
    private readonly LoginViewModel _viewModel;

    public LoginWindow(LoginViewModel viewModel)
    {
        InitializeComponent();
        _viewModel = viewModel;
        DataContext = viewModel;
        Loaded += (_, _) => PasswordInput.Focus();
    }

    private void PasswordInput_OnPasswordChanged(object sender, RoutedEventArgs e)
    {
        _viewModel.Password = PasswordInput.Password;
    }

    protected override void OnKeyDown(KeyEventArgs e)
    {
        if (e.Key == Key.Enter && !_viewModel.IsBusy)
        {
            _viewModel.Password = PasswordInput.Password;
            if (_viewModel.LoginCommand.CanExecute(null))
            {
                _viewModel.LoginCommand.Execute(null);
            }
        }

        base.OnKeyDown(e);
    }
}
