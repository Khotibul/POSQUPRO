using System.Collections.ObjectModel;
using System.Windows.Input;
using Posqupro.Desktop.Models;
using Posqupro.Desktop.Services;

namespace Posqupro.Desktop.ViewModels;

public sealed class ParkedViewModel : ViewModelBase
{
    private readonly ShellViewModel _shell;
    private ParkedTransaction? _selected;

    public ParkedViewModel(ShellViewModel shell)
    {
        _shell = shell;
        Items = [];
        RestoreCommand = new AsyncRelayCommand(RestoreAsync, () => _selected is not null);
        DeleteCommand = new AsyncRelayCommand(DeleteAsync, () => _selected is not null);
        RefreshCommand = new AsyncRelayCommand(LoadAsync);
        _ = LoadAsync();
    }

    public ObservableCollection<ParkedTransaction> Items { get; }
    public ICommand RestoreCommand { get; }
    public ICommand DeleteCommand { get; }
    public ICommand RefreshCommand { get; }

    public ParkedTransaction? Selected
    {
        get => _selected;
        set
        {
            if (SetProperty(ref _selected, value))
            {
                OnPropertyChanged(nameof(SelectedItems));
            }
        }
    }

    public IReadOnlyList<CartLineDto> SelectedItems => Selected?.Items ?? [];

    private async Task LoadAsync()
    {
        Items.Clear();
        foreach (var parked in await AppServices.Queries.GetParkedAsync())
        {
            Items.Add(parked);
        }
    }

    private async Task RestoreAsync()
    {
        if (Selected is null)
        {
            return;
        }

        var lines = await AppServices.Sales.RestoreParkedAsync(Selected.Id);
        if (lines.Count == 0)
        {
            Ui.Error("Transaksi tertunda tidak memiliki item.");
            return;
        }

        var pos = _shell.EnsurePos();
        pos.LoadLines(lines);
        await LoadAsync();
        _shell.Navigate("pos");
        pos.StatusMessage = "Transaksi tertunda dipulihkan ke keranjang.";
    }

    private async Task DeleteAsync()
    {
        if (Selected is null || !Ui.Confirm("Hapus transaksi tertunda ini?", "Hapus"))
        {
            return;
        }

        await AppServices.Sales.DeleteParkedAsync(Selected);
        Selected = null;
        await LoadAsync();
        await AppServices.Sync.RefreshCountersAsync();
    }
}
