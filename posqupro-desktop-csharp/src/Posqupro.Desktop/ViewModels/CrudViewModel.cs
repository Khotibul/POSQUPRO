using System.Collections.ObjectModel;
using System.Globalization;
using System.Text.Json;
using System.Windows;
using System.Windows.Input;
using Posqupro.Desktop.Models;
using Posqupro.Desktop.Services;

namespace Posqupro.Desktop.ViewModels;

public enum FieldKind
{
    Text,
    Number,
    Decimal,
    Bool,
    Choice,
    TextChoice,
    Password,
    Date,
}

public sealed class ChoiceOption(long id, string label)
{
    public long Id { get; } = id;
    public string Label { get; } = label;
    public override string ToString() => Label;
}

public sealed class FieldDef
{
    public required string Key { get; init; }
    public required string Label { get; init; }
    public FieldKind Kind { get; init; } = FieldKind.Text;
    public bool Required { get; init; }
    public string? Placeholder { get; init; }
    public Func<Task<List<ChoiceOption>>>? OptionsLoader { get; init; }
    public string[]? TextOptions { get; init; }
    public bool ShowInEdit { get; init; } = true;
    public bool IsApiField { get; init; } = true;
}

public sealed class CrudColumn
{
    public required string Key { get; init; }
    public required string Header { get; init; }
    public double Width { get; init; } = 120;
    public bool Bold { get; init; }
    public string? StringFormat { get; init; }
}

public sealed class CrudDefinition
{
    public required string Title { get; init; }
    public required string Entity { get; init; }
    public required string Table { get; init; }
    public required string Resource { get; init; }
    public required string SelectSql { get; init; }
    public required List<FieldDef> Fields { get; init; }
    public required List<CrudColumn> Columns { get; init; }
    public string OrderBy { get; init; } = " ORDER BY 1 DESC";
    public string[] SearchColumns { get; init; } = [];
    public bool CanCreate { get; init; } = true;
    public bool CanDelete { get; init; } = true;
    public Func<Dictionary<string, object?>, Dictionary<string, object?>>? PayloadTransform { get; init; }
    public Func<CrudViewModel, Dictionary<string, object?>, Task>? BeforeSave { get; init; }
}

public sealed class CrudItem
{
    public Dictionary<string, object?> Values { get; set; } = new(StringComparer.OrdinalIgnoreCase);

    public long Id => Values.TryGetValue("id", out var value) && value is not null
        ? Convert.ToInt64(value, CultureInfo.InvariantCulture)
        : 0;

    public object? this[string key]
    {
        get => Values.TryGetValue(key, out var value) ? value : null;
        set => Values[key] = value;
    }
}

public sealed class CrudViewModel : ViewModelBase
{
    private readonly ShellViewModel _shell;
    private readonly LocalDatabaseAccess _access;
    private string _search = "";
    private CrudItem? _selected;
    private CrudItem? _editing;
    private bool _isEditing;
    private int _editingVersion;

    public CrudViewModel(CrudDefinition definition, ShellViewModel shell)
    {
        Definition = definition;
        _shell = shell;
        _access = new LocalDatabaseAccess();
        Items = [];
        SaveCommand = new AsyncRelayCommand(SaveAsync, () => _editing is not null);
        DeleteCommand = new AsyncRelayCommand(DeleteAsync, () => _selected is not null);
        AddCommand = new RelayCommand(BeginAdd, () => Definition.CanCreate);
        EditCommand = new RelayCommand(BeginEdit, () => _selected is not null);
        CancelCommand = new RelayCommand(CancelEdit);
        RefreshCommand = new AsyncRelayCommand(LoadAsync);
        _ = LoadAsync();
    }

    public CrudDefinition Definition { get; }
    public ObservableCollection<CrudItem> Items { get; }
    public ICommand SaveCommand { get; }
    public ICommand DeleteCommand { get; }
    public ICommand AddCommand { get; }
    public ICommand EditCommand { get; }
    public ICommand CancelCommand { get; }
    public ICommand RefreshCommand { get; }

    public string Title => Definition.Title;
    public bool CanCreate => Definition.CanCreate;
    public bool CanDelete => Definition.CanDelete;

    public string Search
    {
        get => _search;
        set
        {
            if (SetProperty(ref _search, value))
            {
                _ = LoadAsync();
            }
        }
    }

    public CrudItem? Selected
    {
        get => _selected;
        set => SetProperty(ref _selected, value);
    }

    public CrudItem? Editing
    {
        get => _editing;
        private set
        {
            if (SetProperty(ref _editing, value))
            {
                EditingVersion++;
            }
        }
    }

    public int EditingVersion
    {
        get => _editingVersion;
        private set => SetProperty(ref _editingVersion, value);
    }

    public bool IsEditing
    {
        get => _isEditing;
        private set => SetProperty(ref _isEditing, value);
    }

    public async Task LoadAsync()
    {
        var sql = Definition.SelectSql;
        object? args = null;

        if (!string.IsNullOrWhiteSpace(Search) && Definition.SearchColumns.Length > 0)
        {
            var clauses = Definition.SearchColumns.Select((column, index) => $"{column} LIKE $search");
            sql += (sql.Contains(" WHERE ", StringComparison.OrdinalIgnoreCase) ? " AND " : " WHERE ") +
                   string.Join(" OR ", clauses);
            args = new { search = $"%{Search.Trim()}%" };
        }

        sql += Definition.OrderBy;
        var rows = await AppServices.Db.QueryRowsAsync(sql, args);
        Items.Clear();
        foreach (var row in rows)
        {
            Items.Add(new CrudItem { Values = row });
        }
    }

    public async Task<List<ChoiceOption>> GetOptionsAsync(FieldDef field)
    {
        if (field.OptionsLoader is null)
        {
            return [];
        }

        return await field.OptionsLoader();
    }

    private void BeginAdd()
    {
        var item = new CrudItem();
        foreach (var field in Definition.Fields)
        {
            item.Values[field.Key] = DefaultFor(field);
        }

        Editing = item;
        IsEditing = true;
    }

    private void BeginEdit()
    {
        if (Selected is null)
        {
            return;
        }

        var clone = new CrudItem();
        foreach (var field in Definition.Fields)
        {
            var raw = Selected.Values.TryGetValue(field.Key, out var value) ? value : null;
            clone.Values[field.Key] = CoerceForField(raw, field, Selected);
        }

        clone.Values["id"] = Selected.Id;
        Editing = clone;
        IsEditing = true;
    }

    private void CancelEdit()
    {
        Editing = null;
        IsEditing = false;
    }

    private async Task SaveAsync()
    {
        if (Editing is null)
        {
            return;
        }

        foreach (var field in Definition.Fields.Where(field => field.Required && field.ShowInEdit))
        {
            var value = Editing[field.Key];
            if (value is null || (value is string text && string.IsNullOrWhiteSpace(text)))
            {
                Ui.Error($"{field.Label} wajib diisi.");
                return;
            }
        }

        var values = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
        foreach (var field in Definition.Fields)
        {
            values[field.Key] = Normalize(Editing[field.Key], field);
        }

        if (Definition.BeforeSave is not null)
        {
            await Definition.BeforeSave(this, values);
        }

        var isNew = Editing.Id == 0;
        var payload = Definition.Fields
            .Where(field => field.IsApiField && field.ShowInEdit)
            .ToDictionary(field => field.Key, field => values.GetValueOrDefault(field.Key));

        if (Definition.PayloadTransform is not null)
        {
            payload = Definition.PayloadTransform(values);
        }

        long localId;
        if (isNew)
        {
            if (Definition.Table == "products" && string.IsNullOrWhiteSpace(values.GetValueOrDefault("sku")?.ToString()))
            {
                values["sku"] = $"SKU-{DateTime.Now:yyMMddHHmmss}";
                payload["sku"] = values["sku"];
            }

            localId = await AppServices.Db.InsertAsync(Definition.Table, values);
        }
        else
        {
            localId = Editing.Id;
            var updates = values.Where(pair => !string.Equals(pair.Key, "id", StringComparison.OrdinalIgnoreCase))
                .ToDictionary(pair => pair.Key, pair => pair.Value);
            await AppServices.Db.UpdateAsync(Definition.Table, localId, updates);
        }

        await AppServices.Db.EnqueueAsync(
            Definition.Entity,
            isNew ? "create" : "update",
            localId,
            payload);

        CancelEdit();
        await LoadAsync();
        StatusMessage = isNew ? "Data baru disimpan." : "Perubahan disimpan.";
        await AppServices.Sync.RefreshCountersAsync();
    }

    private async Task DeleteAsync()
    {
        if (Selected is null)
        {
            return;
        }

        if (!Ui.Confirm($"Hapus data ini?\n\n{Selected.Values.GetValueOrDefault("name") ?? Selected.Values.GetValueOrDefault("category")}", "Hapus"))
        {
            return;
        }

        var serverId = Selected.Values.GetValueOrDefault("server_id");
        var localId = Selected.Id;
        await AppServices.Db.DeleteAsync(Definition.Table, localId);

        if (serverId is not null && Convert.ToInt64(serverId, CultureInfo.InvariantCulture) > 0)
        {
            await AppServices.Db.EnqueueAsync(Definition.Entity, "delete", localId, new
            {
                server_id = Convert.ToInt64(serverId, CultureInfo.InvariantCulture),
            });
        }

        Selected = null;
        await LoadAsync();
        StatusMessage = "Data dihapus.";
        await AppServices.Sync.RefreshCountersAsync();
    }

    private static object? DefaultFor(FieldDef field) => field.Kind switch
    {
        FieldKind.Bool => true,
        FieldKind.Choice => null,
        FieldKind.TextChoice => "",
        FieldKind.Number => 0L,
        FieldKind.Decimal => 0m,
        FieldKind.Date => DateTime.Today,
        FieldKind.Password => "",
        _ => "",
    };

    private static object? CoerceForField(object? raw, FieldDef field, CrudItem source)
    {
        if (field.Kind == FieldKind.Choice && raw is null && field.Key == "category_id")
        {
            return null;
        }

        return field.Kind switch
        {
            FieldKind.Bool => raw is long number ? number != 0 : Convert.ToBoolean(raw ?? false),
            FieldKind.Number => raw is null ? 0L : Convert.ToInt64(raw, CultureInfo.InvariantCulture),
            FieldKind.Decimal => raw is null ? 0m : Convert.ToDecimal(raw, CultureInfo.InvariantCulture),
            FieldKind.Date => raw switch
            {
                DateTime date => date,
                string text when DateTime.TryParse(text, out var parsed) => parsed,
                _ => (DateTime?)null,
            },
            FieldKind.Choice => raw is null ? null : Convert.ToInt64(raw, CultureInfo.InvariantCulture),
            FieldKind.TextChoice => raw?.ToString() ?? "",
            FieldKind.Password => "",
            _ => raw?.ToString() ?? "",
        };
    }

    private static object? Normalize(object? value, FieldDef field) => field.Kind switch
    {
        FieldKind.Bool => value is bool boolean ? boolean : false,
        FieldKind.Number => value is null ? 0L : Convert.ToInt64(value, CultureInfo.InvariantCulture),
        FieldKind.Decimal => value is null ? 0m : Convert.ToDecimal(value, CultureInfo.InvariantCulture),
        FieldKind.Date => value is DateTime date ? date : null,
        FieldKind.Choice => value is null ? null : Convert.ToInt64(value, CultureInfo.InvariantCulture),
        FieldKind.TextChoice => value?.ToString()?.Trim(),
        _ => value?.ToString()?.Trim(),
    };
}

/// <summary>Small indirection to keep view models testable without static access everywhere.</summary>
internal sealed class LocalDatabaseAccess
{
    public Data.LocalDatabase Database => AppServices.Db;
}
