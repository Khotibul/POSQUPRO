using System.Windows.Input;
using Posqupro.Desktop.Services;

namespace Posqupro.Desktop.ViewModels;

public sealed class LoginViewModel : ViewModelBase
{
    public LoginViewModel()
    {
        BaseUrl = AppServices.Settings.NormalizedBaseUrl;
        Email = AppServices.Settings.Value.RememberedEmail ?? "";
        LoginCommand = new AsyncRelayCommand(LoginAsync, () => !IsBusy);
        OfflineLoginCommand = new RelayCommand(LoginOffline, () => !IsBusy);
        IsConfigured = !string.IsNullOrWhiteSpace(AppServices.Settings.Value.UserEmail);
    }

    public event Action? LoggedIn;

    private string _baseUrl = "";
    private string _email = "";
    private bool _isConfigured;
    private string _hint = "";

    public string BaseUrl
    {
        get => _baseUrl;
        set => SetProperty(ref _baseUrl, value);
    }

    public string Email
    {
        get => _email;
        set => SetProperty(ref _email, value);
    }

    public string Password { get; set; } = "";

    public bool IsConfigured
    {
        get => _isConfigured;
        private set => SetProperty(ref _isConfigured, value);
    }

    public string Hint
    {
        get => _hint;
        private set => SetProperty(ref _hint, value);
    }

    public string AppVersion => "Desktop 1.0 · Offline-first";

    public string ConnectionLabel => $"Server: {AppServices.Settings.NormalizedBaseUrl}";

    public ICommand LoginCommand { get; }
    public ICommand OfflineLoginCommand { get; }

    private async Task LoginAsync()
    {
        if (string.IsNullOrWhiteSpace(Email) || string.IsNullOrWhiteSpace(Password))
        {
            Hint = "Email dan password wajib diisi.";
            return;
        }

        IsBusy = true;
        Hint = "Menghubungkan ke server...";
        try
        {
            AppServices.Settings.Value.BaseUrl = BaseUrl.Trim();
            AppServices.Settings.Save();

            var (success, message) = await AppServices.Auth.LoginAsync(Email.Trim(), Password);
            Hint = message;
            if (!success)
            {
                return;
            }

            IsConfigured = true;
            await AppServices.Queries.EnsureDefaultSettingsAsync();
            LoggedIn?.Invoke();
        }
        finally
        {
            IsBusy = false;
        }
    }

    private void LoginOffline()
    {
        var (success, message) = AppServices.Auth.LoginOffline(Email.Trim(), Password);
        Hint = message;
        if (success)
        {
            LoggedIn?.Invoke();
        }
    }
}
