using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace Posqupro.Desktop.Services;

public sealed class ApiResult
{
    public bool Success { get; init; }
    public bool Offline { get; init; }
    public int StatusCode { get; init; }
    public string Message { get; init; } = "";
    public JsonElement Data { get; init; }
    public bool Unauthorized => StatusCode == (int)HttpStatusCode.Unauthorized;

    public static ApiResult Ok(JsonElement data, int status = 200) =>
        new() { Success = true, StatusCode = status, Data = data };

    public static ApiResult Fail(string message, int status = 0, bool offline = false) =>
        new() { Success = false, StatusCode = status, Message = message, Offline = offline };
}

/// <summary>Thin HTTP client for the POSQUPRO Laravel API (Sanctum bearer tokens).</summary>
public sealed class ApiClient(AppSettingsStore settings)
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);
    private readonly AppSettingsStore _settings = settings;
    private readonly HttpClient _http = new() { Timeout = TimeSpan.FromSeconds(40) };

    public async Task<ApiResult> PingAsync()
    {
        var result = await SendAsync(HttpMethod.Get, "api/health", null, auth: false, timeout: TimeSpan.FromSeconds(8));
        return result;
    }

    public async Task<ApiResult> LoginAsync(string email, string password)
    {
        return await SendAsync(
            HttpMethod.Post,
            "api/v1/login",
            new { email, password },
            auth: false,
            timeout: TimeSpan.FromSeconds(25));
    }

    public async Task<ApiResult> LogoutAsync()
    {
        return await SendAsync(HttpMethod.Post, "api/v1/logout", new { }, auth: true);
    }

    public Task<ApiResult> GetAsync(string path) => SendAsync(HttpMethod.Get, $"api/v1/{path.TrimStart('/')}", null);

    public Task<ApiResult> PostAsync(string path, object? payload) =>
        SendAsync(HttpMethod.Post, $"api/v1/{path.TrimStart('/')}", payload ?? new { });

    public Task<ApiResult> PutAsync(string path, object? payload) =>
        SendAsync(HttpMethod.Put, $"api/v1/{path.TrimStart('/')}", payload ?? new { });

    public Task<ApiResult> DeleteAsync(string path) =>
        SendAsync(HttpMethod.Delete, $"api/v1/{path.TrimStart('/')}", null);

    public async Task<List<JsonElement>> GetAllPagesAsync(string path, int maxPages = 40, string? extraQuery = null)
    {
        var rows = new List<JsonElement>();
        for (var page = 1; page <= maxPages; page++)
        {
            var query = $"{(extraQuery is null ? "?" : "&")}page={page}";
            var result = await GetAsync($"{path}{query}");
            if (!result.Success || result.Data.ValueKind != JsonValueKind.Object)
            {
                break;
            }

            if (!result.Data.TryGetProperty("data", out var data) || data.ValueKind != JsonValueKind.Array)
            {
                break;
            }

            var pageRows = data.EnumerateArray().Select(row => row.Clone()).ToList();
            rows.AddRange(pageRows);

            var lastPage = result.Data.TryGetProperty("last_page", out var last) && last.TryGetInt32(out var parsed) ? parsed : page;
            if (pageRows.Count == 0 || page >= lastPage)
            {
                break;
            }
        }

        return rows;
    }

    private async Task<ApiResult> SendAsync(
        HttpMethod method,
        string path,
        object? payload,
        bool auth = true,
        TimeSpan? timeout = null)
    {
        try
        {
            using var request = new HttpRequestMessage(method, $"{_settings.NormalizedBaseUrl}/{path}");
            request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

            if (auth && !string.IsNullOrWhiteSpace(_settings.Value.Token))
            {
                request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _settings.Value.Token);
            }

            if (payload is not null)
            {
                request.Content = new StringContent(
                    JsonSerializer.Serialize(payload, JsonOptions),
                    Encoding.UTF8,
                    "application/json");
            }

            using var cancellation = new CancellationTokenSource(timeout ?? TimeSpan.FromSeconds(40));
            using var response = await _http.SendAsync(request, cancellation.Token);
            var body = await response.Content.ReadAsStringAsync(cancellation.Token);
            var data = Parse(body);

            if (response.IsSuccessStatusCode)
            {
                return ApiResult.Ok(data, (int)response.StatusCode);
            }

            var message = ExtractMessage(data, response.StatusCode);
            return ApiResult.Fail(message, (int)response.StatusCode);
        }
        catch (TaskCanceledException)
        {
            return ApiResult.Fail("Koneksi ke server timeout. Periksa jaringan Anda.", offline: true);
        }
        catch (HttpRequestException)
        {
            return ApiResult.Fail("Server tidak dapat dijangkau. Aplikasi berjalan dalam mode offline.", offline: true);
        }
        catch (Exception exception)
        {
            return ApiResult.Fail(exception.Message);
        }
    }

    private static JsonElement Parse(string body)
    {
        if (string.IsNullOrWhiteSpace(body))
        {
            return default;
        }

        try
        {
            using var document = JsonDocument.Parse(body);
            return document.RootElement.Clone();
        }
        catch (JsonException)
        {
            return default;
        }
    }

    private static string ExtractMessage(JsonElement data, HttpStatusCode status)
    {
        if (data.ValueKind == JsonValueKind.Object)
        {
            if (data.TryGetProperty("message", out var message) && message.ValueKind == JsonValueKind.String)
            {
                var text = message.GetString() ?? "";
                if (data.TryGetProperty("errors", out var errors) && errors.ValueKind == JsonValueKind.Object)
                {
                    var first = errors.EnumerateObject()
                        .SelectMany(property => property.Value.ValueKind == JsonValueKind.Array
                            ? property.Value.EnumerateArray().Select(item => item.GetString())
                            : [property.Value.GetString()])
                        .FirstOrDefault(value => !string.IsNullOrWhiteSpace(value));
                    if (!string.IsNullOrWhiteSpace(first))
                    {
                        return $"{text} {first}";
                    }
                }

                return text;
            }
        }

        return status switch
        {
            HttpStatusCode.Unauthorized => "Sesi berakhir. Silakan login kembali.",
            HttpStatusCode.Forbidden => "Anda tidak memiliki akses ke fitur ini.",
            HttpStatusCode.NotFound => "Data tidak ditemukan di server.",
            _ => $"Permintaan gagal ({(int)status}).",
        };
    }
}
