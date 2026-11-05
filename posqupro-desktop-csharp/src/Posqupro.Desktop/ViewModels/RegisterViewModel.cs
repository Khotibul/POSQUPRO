using System.Collections.ObjectModel;
using System.Windows.Input;
using Posqupro.Desktop.Models;
using Posqupro.Desktop.Services;
using Posqupro.Desktop.Views.Dialogs;

namespace Posqupro.Desktop.ViewModels;

public sealed class RegisterViewModel : ViewModelBase
{
    private Register? _selectedRegister;
    private RegisterSession? _openSession;
    private RegisterSession? _selectedSession;

    public RegisterViewModel()
    {
        Registers = [];
        Sessions = [];
        OpenRegisterCommand = new AsyncRelayCommand(OpenRegisterAsync, () => _selectedRegister is not null && _openSession is null);
        CloseRegisterCommand = new AsyncRelayCommand(CloseRegisterAsync, () => _openSession is not null);
        RefreshCommand = new AsyncRelayCommand(LoadAsync);
        _ = LoadAsync();
    }

    public ObservableCollection<Register> Registers { get; }
    public ObservableCollection<RegisterSession> Sessions { get; }
    public ICommand OpenRegisterCommand { get; }
    public ICommand CloseRegisterCommand { get; }
    public ICommand RefreshCommand { get; }

    public Register? SelectedRegister
    {
        get => _selectedRegister;
        set
        {
            if (SetProperty(ref _selectedRegister, value))
            {
                _ = LoadOpenSessionAsync();
            }
        }
    }

    public RegisterSession? OpenSession
    {
        get => _openSession;
        private set
        {
            if (SetProperty(ref _openSession, value))
            {
                OnPropertyChanged(nameof(SessionStatusLabel));
                OnPropertyChanged(nameof(HasOpenSession));
            }
        }
    }

    public RegisterSession? SelectedSession
    {
        get => _selectedSession;
        set => SetProperty(ref _selectedSession, value);
    }

    public bool HasOpenSession => OpenSession is not null;

    public string SessionStatusLabel => OpenSession is null
        ? "Belum ada sesi kas yang terbuka."
        : $"Sesi terbuka sejak {OpenSession.OpenedAt:dd MMM HH:mm} · Modal awal Rp {OpenSession.OpeningFloat:N0}";

    private async Task LoadAsync()
    {
        var registers = await AppServices.Queries.GetRegistersAsync();
        Registers.Clear();
        foreach (var register in registers)
        {
            Registers.Add(register);
        }

        if (SelectedRegister is null || !Registers.Any(candidate => candidate.Id == SelectedRegister.Id))
        {
            SelectedRegister = Registers.FirstOrDefault();
        }

        var sessions = await AppServices.Queries.GetRegisterSessionsAsync();
        Sessions.Clear();
        foreach (var session in sessions)
        {
            Sessions.Add(session);
        }

        await LoadOpenSessionAsync();
    }

    private async Task LoadOpenSessionAsync()
    {
        OpenSession = SelectedRegister is null
            ? null
            : await AppServices.Queries.GetOpenSessionAsync(SelectedRegister.Id);
    }

    private async Task OpenRegisterAsync()
    {
        if (SelectedRegister is null)
        {
            return;
        }

        var values = PromptWindow.Ask(
            System.Windows.Application.Current.MainWindow,
            "Buka Kas / Shift",
            $"Register: {SelectedRegister.Name}",
            new PromptField("opening_float", "Modal Awal (Rp)", "0"),
            new PromptField("notes", "Catatan", ""));

        if (values is null)
        {
            return;
        }

        if (!decimal.TryParse(values["opening_float"], out var openingFloat) || openingFloat < 0)
        {
            Ui.Error("Modal awal tidak valid.");
            return;
        }

        await AppServices.Sales.OpenRegisterAsync(
            SelectedRegister.Id,
            openingFloat,
            string.IsNullOrWhiteSpace(values["notes"]) ? null : values["notes"]);

        StatusMessage = "Sesi kas dibuka.";
        await LoadAsync();
        await AppServices.Sync.RefreshCountersAsync();
        CommandManager.InvalidateRequerySuggested();
    }

    private async Task CloseRegisterAsync()
    {
        if (OpenSession is null)
        {
            return;
        }

        var values = PromptWindow.Ask(
            System.Windows.Application.Current.MainWindow,
            "Tutup Kas / Shift",
            $"Modal awal Rp {OpenSession.OpeningFloat:N0}. Masukkan uang fisik di laci.",
            new PromptField("actual_cash", "Uang Aktual (Rp)", "0"),
            new PromptField("notes", "Catatan", ""));

        if (values is null)
        {
            return;
        }

        if (!decimal.TryParse(values["actual_cash"], out var actualCash) || actualCash < 0)
        {
            Ui.Error("Jumlah uang aktual tidak valid.");
            return;
        }

        await AppServices.Sales.CloseRegisterAsync(
            OpenSession,
            actualCash,
            string.IsNullOrWhiteSpace(values["notes"]) ? null : values["notes"]);

        StatusMessage = "Sesi kas ditutup.";
        await LoadAsync();
        await AppServices.Sync.RefreshCountersAsync();
        CommandManager.InvalidateRequerySuggested();
    }
}
