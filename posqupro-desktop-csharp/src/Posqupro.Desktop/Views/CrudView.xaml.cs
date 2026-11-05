using System.Globalization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Media;
using Posqupro.Desktop.ViewModels;

namespace Posqupro.Desktop.Views;

/// <summary>Shared master-data screen: dynamic grid columns + dynamic edit form.</summary>
public partial class CrudView : UserControl
{
    private CrudViewModel? _viewModel;

    public CrudView()
    {
        InitializeComponent();
        DataContextChanged += OnDataContextChanged;
    }

    private void OnDataContextChanged(object sender, DependencyPropertyChangedEventArgs e)
    {
        if (_viewModel is not null)
        {
            _viewModel.PropertyChanged -= OnViewModelPropertyChanged;
        }

        _viewModel = e.NewValue as CrudViewModel;
        if (_viewModel is not null)
        {
            _viewModel.PropertyChanged += OnViewModelPropertyChanged;
            RebuildColumns();
            RebuildFields();
        }
    }

    private void OnViewModelPropertyChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
    {
        if (e.PropertyName is nameof(CrudViewModel.IsEditing) or nameof(CrudViewModel.EditingVersion))
        {
            RebuildFields();
        }
    }

    private void RebuildColumns()
    {
        if (_viewModel is null)
        {
            return;
        }

        Grid.Columns.Clear();
        Grid.Columns.Add(new DataGridTextColumn
        {
            Header = "ID",
            Binding = new Binding("Id"),
            Width = 60,
        });

        foreach (var column in _viewModel.Definition.Columns)
        {
            var binding = new Binding($"Values[{column.Key}]")
            {
                StringFormat = column.StringFormat,
            };

            var textColumn = new DataGridTextColumn
            {
                Header = column.Header,
                Binding = binding,
                Width = new DataGridLength(column.Width),
            };

            if (column.Bold)
            {
                textColumn.ElementStyle = CreateBoldStyle();
            }

            Grid.Columns.Add(textColumn);
        }
    }

    private static Style CreateBoldStyle()
    {
        var style = new Style(typeof(TextBlock));
        style.Setters.Add(new Setter(TextBlock.FontWeightProperty, FontWeights.SemiBold));
        return style;
    }

    private void RebuildFields()
    {
        FieldsPanel.Children.Clear();
        if (_viewModel?.Editing is null || _viewModel.Definition.Fields.Count == 0)
        {
            return;
        }

        var editing = _viewModel.Editing;
        foreach (var field in _viewModel.Definition.Fields.Where(item => item.ShowInEdit))
        {
            var label = new TextBlock
            {
                Text = field.Required ? $"{field.Label} *" : field.Label,
                Style = (Style)Application.Current.FindResource("CardTitle"),
                Margin = new Thickness(0, 0, 0, 6),
            };
            FieldsPanel.Children.Add(label);

            var control = CreateFieldControl(field, editing);
            if (control is not null)
            {
                control.Margin = new Thickness(0, 0, 0, 4);
                FieldsPanel.Children.Add(control);
            }
        }
    }

    private FrameworkElement? CreateFieldControl(FieldDef field, CrudItem editing)
    {
        var value = editing[field.Key];

        switch (field.Kind)
        {
            case FieldKind.Bool:
            {
                var checkbox = new CheckBox
                {
                    IsChecked = value is bool b ? b : value is long l && l != 0,
                    Content = "Aktif",
                    Style = (Style)Application.Current.FindResource("Switch"),
                };
                checkbox.Checked += (_, _) => editing[field.Key] = true;
                checkbox.Unchecked += (_, _) => editing[field.Key] = false;
                return checkbox;
            }

            case FieldKind.Choice:
            {
                var combo = new ComboBox { Margin = new Thickness(0, 0, 0, 0) };
                _ = LoadOptionsAsync(field, combo, value);
                combo.SelectionChanged += (_, _) =>
                {
                    editing[field.Key] = combo.SelectedItem is ChoiceOption option ? option.Id : null;
                };
                return combo;
            }

            case FieldKind.TextChoice:
            {
                var combo = new ComboBox();
                foreach (var option in field.TextOptions ?? [])
                {
                    combo.Items.Add(option);
                }

                combo.SelectedItem = value?.ToString() is { Length: > 0 } text && (field.TextOptions ?? []).Contains(text)
                    ? text
                    : (field.TextOptions ?? []).FirstOrDefault();
                combo.SelectionChanged += (_, _) => editing[field.Key] = combo.SelectedItem?.ToString() ?? "";
                return combo;
            }

            case FieldKind.Decimal:
            case FieldKind.Number:
            {
                var box = new TextBox
                {
                    Text = FormatNumber(value),
                    Style = (Style)Application.Current.FindResource("Input"),
                };
                box.LostFocus += (_, _) => editing[field.Key] = ParseNumber(box.Text, field.Kind);
                box.TextChanged += (_, _) => editing[field.Key] = ParseNumber(box.Text, field.Kind);
                return box;
            }

            case FieldKind.Password:
            {
                var box = new PasswordBox();
                box.PasswordChanged += (_, _) => editing[field.Key] = box.Password;
                return box;
            }

            case FieldKind.Date:
            {
                var picker = new DatePicker
                {
                    SelectedDate = value switch
                    {
                        DateTime date => date,
                        string text when DateTime.TryParse(text, out var parsed) => parsed,
                        _ => null,
                    },
                };
                picker.SelectedDateChanged += (_, _) => editing[field.Key] = picker.SelectedDate;
                return picker;
            }

            default:
            {
                var box = new TextBox
                {
                    Text = value?.ToString() ?? "",
                    Style = (Style)Application.Current.FindResource("Input"),
                    AcceptsReturn = field.Key is "description" or "notes" or "address",
                };
                box.LostFocus += (_, _) => editing[field.Key] = box.Text;
                return box;
            }
        }
    }

    private static string FormatNumber(object? value) => value switch
    {
        null => "0",
        decimal d => d.ToString(CultureInfo.InvariantCulture),
        long l => l.ToString(CultureInfo.InvariantCulture),
        int i => i.ToString(CultureInfo.InvariantCulture),
        _ => value.ToString() ?? "",
    };

    private static object ParseNumber(string text, FieldKind kind)
    {
        if (!decimal.TryParse(text, NumberStyles.Number, CultureInfo.InvariantCulture, out var parsed))
        {
            parsed = 0;
        }

        return kind == FieldKind.Number ? (object)(long)parsed : parsed;
    }

    private static async Task LoadOptionsAsync(FieldDef field, ComboBox combo, object? selected)
    {
        if (field.OptionsLoader is null)
        {
            return;
        }

        var options = await field.OptionsLoader();
        combo.DisplayMemberPath = nameof(ChoiceOption.Label);
        combo.ItemsSource = options;
        if (selected is long id)
        {
            combo.SelectedItem = options.FirstOrDefault(option => option.Id == id);
        }
    }
}
