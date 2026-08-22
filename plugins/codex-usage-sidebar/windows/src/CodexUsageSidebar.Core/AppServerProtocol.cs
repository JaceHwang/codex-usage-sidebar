using System.Text.Json;

namespace CodexUsageSidebar.Core;

public sealed class AppServerProtocol
{
    private readonly string clientName;
    private readonly string clientVersion;
    private int nextRequestId = 1;

    public AppServerProtocol(string clientName, string clientVersion)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(clientName);
        ArgumentException.ThrowIfNullOrWhiteSpace(clientVersion);
        this.clientName = clientName;
        this.clientVersion = clientVersion;
    }

    public string CreateInitializeRequest() => JsonSerializer.Serialize(new
    {
        id = nextRequestId++,
        method = "initialize",
        @params = new
        {
            clientInfo = new { name = clientName, version = clientVersion },
            capabilities = new { experimentalApi = true },
        },
    });

    public string CreateInitializedNotification() => JsonSerializer.Serialize(new
    {
        method = "initialized",
        @params = new { },
    });

    public JsonRpcRequest CreateRateLimitRead()
    {
        var id = nextRequestId++;
        return new JsonRpcRequest(id, JsonSerializer.Serialize(new
        {
            id,
            method = "account/rateLimits/read",
            @params = new { },
        }));
    }

    public string CreateRateLimitReadRequest() => CreateRateLimitRead().Json;

    public JsonRpcRequest CreateTokenUsageRead()
    {
        var id = nextRequestId++;
        return new JsonRpcRequest(id, JsonSerializer.Serialize(new
        {
            id,
            method = "account/usage/read",
            @params = new { },
        }));
    }

    public JsonRpcRequest CreateAccountRead()
    {
        var id = nextRequestId++;
        return new JsonRpcRequest(id, JsonSerializer.Serialize(new
        {
            id,
            method = "account/read",
            @params = new { },
        }));
    }

    public AllowanceSnapshot? DecodeSnapshot(string line, DateTimeOffset receivedAt)
    {
        try
        {
            using var document = JsonDocument.Parse(line);
            var root = document.RootElement;
            if (root.TryGetProperty("method", out var method)
                && method.ValueKind == JsonValueKind.String
                && method.GetString() == "account/rateLimits/updated")
            {
                return RateLimitDecoder.DecodeNotification(line, receivedAt);
            }
            if (root.TryGetProperty("result", out _))
            {
                return RateLimitDecoder.DecodeResponse(line, receivedAt);
            }
        }
        catch (JsonException)
        {
        }
        catch (RateLimitDecodingException)
        {
        }
        return null;
    }

    public TokenUsageSnapshot? DecodeTokenUsage(string line, DateTimeOffset receivedAt)
    {
        try
        {
            using var document = JsonDocument.Parse(line);
            var root = document.RootElement;
            if (root.TryGetProperty("result", out _)
                || root.TryGetProperty("error", out _))
            {
                return TokenUsageDecoder.DecodeResponse(line, receivedAt);
            }
        }
        catch (JsonException)
        {
        }
        return null;
    }

    public AccountIdentity? DecodeAccount(string line)
    {
        try
        {
            using var document = JsonDocument.Parse(line);
            if (document.RootElement.TryGetProperty("result", out _))
            {
                return AccountIdentityDecoder.DecodeResponse(line);
            }
        }
        catch (JsonException)
        {
        }
        return null;
    }
}

public readonly record struct JsonRpcRequest(int Id, string Json);
