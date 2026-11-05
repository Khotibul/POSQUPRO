using System.Windows;
using System.Windows.Input;
using Posqupro.Desktop.ViewModels;

namespace Posqupro.Desktop;

public partial class MainWindow : Window
{
    private readonly ShellViewModel _shell;

    public MainWindow(ShellViewModel shell)
    {
        InitializeComponent();
        _shell = shell;
        DataContext = shell;
    }

    protected override void OnKeyDown(KeyEventArgs e)
    {
        if (e.Key >= Key.F1 && e.Key <= Key.F12)
        {
            _shell.NavigateByShortcut(e.Key.ToString());
            e.Handled = true;
        }

        base.OnKeyDown(e);
    }

    protected override void OnClosed(EventArgs e)
    {
        base.OnClosed(e);
        Application.Current.Shutdown();
    }
}
