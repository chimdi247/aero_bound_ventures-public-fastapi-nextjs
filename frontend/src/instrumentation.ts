// Next.js auto-detects and runs this file's `register()` export once,
// on server startup, before any other application code -- this is the
// framework's own hook for "zero-code" instrumentation (no need to
// wrap route handlers or fetch calls by hand). See:
// https://nextjs.org/docs/app/building-your-application/optimizing/open-telemetry
//
// @vercel/otel reads the standard OTEL_EXPORTER_OTLP_ENDPOINT /
// OTEL_SERVICE_NAME env vars (set in docker-compose.yml) and wires up
// the OpenTelemetry SDK to export traces for every request, fetch
// call, and server action to the otel-collector.
export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    const { registerOTel } = await import('@vercel/otel');
    registerOTel({
      serviceName: process.env.OTEL_SERVICE_NAME || 'aero-frontend',
    });
  }
}
