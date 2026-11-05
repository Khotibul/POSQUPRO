using System.Collections;
using System.Windows;
using System.Windows.Controls;

namespace Posqupro.Desktop.Views.Dialogs;

public sealed record PromptField(string Key, string Label, string DefaultValue = "");

/// <summary>Small modal dialog that collects one or more named string fields.</summary>
public partial class PromptWindow : Window
{
    private readonly List<PromptField> _fields;
    private readonly Dictionary<string, TextBox> _inputs = new(StringComparer.OrdinalIgnoreCase);

    private PromptWindow(Window owner, string title, string message, IReadOnlyList<PromptField> fields)
    {
        InitializeComponent();
        Owner = owner;
        Title = title;
        MessageText.Text = message;
        _fields = [.. fields];

        foreach (var field in _fields)
        {
            var label = new TextBlock
            {
                Text = field.Label,
                Style = (System.Windows.Style)Application.Current.FindResource("CardTitle"),
                Margin = new Thickness(0, 0, 0, 6),
            };
            FieldsPanel.Children.Add(label);

            var input = new TextBox
            {
                Text = field.DefaultValue,
                Style = (System.Windows.Style)Application.Current.FindResource("Input"),
                Margin = new Thickness(0, 0, 0, 12),
            };
            FieldsPanel.Children.Add(input);
            _inputs[field.Key] = input;
        }
    }

    /// <summary>Opens the dialog and returns the entered values, or null when cancelled.</summary>
    public static Dictionary<string, string>? Ask(
        Window? owner,
        string title,
        string message,
        params PromptField[] fields)
    {
        if (fields.Length == 0)
        {
            fields = [new PromptField("value", "Nilai", "")];
        }

        var window = new PromptWindow(owner ?? Application.Current.MainWindow!, title, message, fields);
        var accepted = window.ShowDialog() == true;
        if (!accepted)
        {
            return null;
        }

        return window._inputs.ToDictionary(pair => pair.Key, pair => pair.Value.Text, StringComparer.OrdinalIgnoreCase);
    }

    private void OnConfirm(object sender, RoutedEventArgs e)
    {
        DialogResult = true;
    }

    private void OnCancel(object sender, RoutedEventArgs e)
    {
        DialogResult = false;
    }
}
