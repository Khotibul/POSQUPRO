using System.Windows;
using System.Windows.Threading;
using Posqupro.Desktop.Services;
using Posqupro.Desktop.ViewModels;
using Posqupro.Desktop.Views;

namespace Posqupro.Desktop;

public partial class App : Application
{
    protected override async void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        DispatcherUnhandledException += OnDispatcherUnhandledException;

        try
        {
            await AppServices.InitializeAsync();
            await AppServices.Queries.EnsureDefaultSettingsAsync();
        }
        catch (Exception exception)
        {
            MessageBox.Show(
                $"Aplikasi gagal menyiapkan database lokal.\n\n{exception.Message}",
                "POSQUPRO Desktop",
                MessageBoxButton.OK,
                MessageBoxImage.Error);
            Shutdown(1);
            return;
        }

        if (AppServices.Auth.IsLoggedIn)
        {
            ShowShell();
        }
        else
        {
            ShowLogin();
        }
    }

    private void ShowLogin()
    {
        var viewModel = new LoginViewModel();
        var window = new LoginWindow(viewModel);
        var loggedIn = false;
        viewModel.LoggedIn += () =>
        {
            loggedIn = true;
            window.Close();
            ShowShell();
        };
        window.Closed += (_, _) =>
        {
            if (!loggedIn)
            {
                Shutdown();
            }
        };
        MainWindow = window;
        window.Show();
    }

    private void ShowShell()
    {
        var shell = new ShellViewModel();
        var window = new MainWindow(shell);
        shell.LoggedOut += () =>
        {
            window.Close();
            ShowLogin();
        };
        MainWindow = window;
        window.Show();
    }

    private static void OnDispatcherUnhandledException(object sender, DispatcherUnhandledExceptionEventArgs e)
    {
        MessageBox.Show(
            $"Terjadi kesalahan tak terduga.\n\n{e.Exception.Message}",
            "POSQUPRO Desktop",
            MessageBoxButton.OK,
            MessageBoxImage.Error);
        e.Handled = true;
    }
}
