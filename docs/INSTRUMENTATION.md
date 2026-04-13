# Connecting Your App

Point your app at the OTel Collector:
- **gRPC:** `http://localhost:4317`
- **HTTP:** `http://localhost:4318`

Set these env vars before starting your app (or add to your `docker-compose.yml`):

```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
OTEL_SERVICE_NAME=my-service
OTEL_RESOURCE_ATTRIBUTES=deployment.environment=development
```

If your app runs inside Docker on the same `observability` network, use `otel-collector` instead of `localhost`:

```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
```

---

## .NET

Auto-instrumentation (zero code changes):

```bash
dotnet add package OpenTelemetry.Extensions.Hosting
dotnet add package OpenTelemetry.Instrumentation.AspNetCore
dotnet add package OpenTelemetry.Instrumentation.Http
dotnet add package OpenTelemetry.Exporter.OpenTelemetryProtocol
```

```csharp
// Program.cs
builder.Services.AddOpenTelemetry()
    .ConfigureResource(r => r.AddService(builder.Environment.ApplicationName))
    .WithTracing(t => t
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddOtlpExporter())
    .WithMetrics(m => m
        .AddAspNetCoreInstrumentation()
        .AddRuntimeInstrumentation()
        .AddOtlpExporter())
    .WithLogging(l => l
        .AddOtlpExporter());
```

---

## Go

```bash
go get go.opentelemetry.io/otel
go get go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc
go get go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp
```

```go
// Minimal setup — see MockMart for a complete example
exporter, _ := otlptracegrpc.New(ctx)
tp := trace.NewTracerProvider(
    trace.WithBatcher(exporter),
    trace.WithResource(resource.NewWithAttributes(
        semconv.SchemaURL,
        semconv.ServiceNameKey.String("my-service"),
    )),
)
otel.SetTracerProvider(tp)
```

---

## Python

```bash
pip install opentelemetry-distro opentelemetry-exporter-otlp
opentelemetry-bootstrap -a install
```

Auto-instrumentation (zero code changes for Flask/FastAPI/Django):

```bash
opentelemetry-instrument \
  --traces_exporter otlp \
  --metrics_exporter otlp \
  --logs_exporter otlp \
  python app.py
```

---

## Node.js

```bash
npm install @opentelemetry/sdk-node @opentelemetry/auto-instrumentations-node @opentelemetry/exporter-trace-otlp-grpc
```

```javascript
// tracing.js (require before app)
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');

const sdk = new NodeSDK({
  serviceName: 'my-service',
  instrumentations: [getNodeAutoInstrumentations()],
});
sdk.start();
```

```bash
node -r ./tracing.js app.js
```

---

## Collector Chaining (agent → gateway)

If your project already has its own OTel Collector handling pre-filtering, enrichment, or routing, you don't need to instrument your app directly against this stack. Point the intermediate collector here as an OTLP exporter:

```yaml
# Your project's collector config
exporters:
  otlp:
    endpoint: http://<kickstart-host>:4317
    tls:
      insecure: true

service:
  pipelines:
    traces:
      receivers: [...]
      processors: [...]
      exporters: [otlp]
    metrics:
      receivers: [...]
      processors: [...]
      exporters: [otlp]
    logs:
      receivers: [...]
      processors: [...]
      exporters: [otlp]
```

Use port `4317` for gRPC or `4318` for HTTP.

> **Note on resource attributes:** the collector in this stack runs a `resourcedetection` processor with `override: false`. If your intermediate collector already adds `host.name`, `os.type`, and similar attributes, they are preserved as-is. No duplicates.

---

## Advanced Example: MockMart

[MockMart](https://github.com/monte97/MockMart) is a fully instrumented Node.js e-commerce microservices app. It includes:
- Distributed tracing across 4 services
- Tail sampling configuration
- PII filtering with OTTL processors
- Playwright E2E tests with trace correlation

Use it as a reference or to generate real traffic for your observability stack.
