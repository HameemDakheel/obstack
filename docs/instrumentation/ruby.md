# Ruby instrumentation

> **What you'll need:** Ruby 3.2+, an obstack stack reachable at `https://<DOMAIN>/`, and the basic-auth credentials from your `.env`.
> **Time to complete:** ~10 minutes.

This guide uses the **`opentelemetry-instrumentation-all`** meta-gem which auto-instruments Rails, Sinatra, ActiveRecord, Net::HTTP, Sidekiq, Redis, PG, mysql2, and ~30 other gems.

---

## Step 1 — Add gems

In your `Gemfile`:

```ruby
gem 'opentelemetry-sdk'
gem 'opentelemetry-exporter-otlp'
gem 'opentelemetry-instrumentation-all'
```

Then:

```bash
bundle install
```

---

## Step 2 — Configure via environment variables

```bash
export OTEL_SERVICE_NAME=my-ruby-app
export OTEL_EXPORTER_OTLP_ENDPOINT=https://<DOMAIN>
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
export OTEL_EXPORTER_OTLP_HEADERS="authorization=Basic $(echo -n 'ingest:YOUR_PASSWORD' | base64)"
```

---

## Step 3 — Initialise the SDK

For Rails, create `config/initializers/opentelemetry.rb`:

```ruby
require 'opentelemetry/sdk'
require 'opentelemetry/exporter/otlp'
require 'opentelemetry/instrumentation/all'

OpenTelemetry::SDK.configure do |c|
  c.service_name = ENV.fetch('OTEL_SERVICE_NAME', 'my-ruby-app')
  c.use_all   # auto-install all available instrumentations
end
```

For non-Rails apps (Sinatra, plain Ruby), require this in your entrypoint before `require`-ing your app's libraries — instrumentation happens at gem-load time.

---

## Step 4 — Run your app

```bash
bundle exec rails server
# or
bundle exec puma
# or for plain Ruby:
ruby app.rb
```

Every Rails controller action becomes a trace. Every ActiveRecord query becomes a child span. HTTP outgoing calls (Net::HTTP, Faraday, HTTParty) are auto-spanned.

---

## Step 5 — Send a manual test span

```ruby
# test_trace.rb
require 'opentelemetry/sdk'
require 'opentelemetry/exporter/otlp'

OpenTelemetry::SDK.configure do |c|
  c.service_name = 'test-ruby-app'
end

tracer = OpenTelemetry.tracer_provider.tracer('test')

tracer.in_span('hello-world') do |span|
  span.set_attribute('greeting', 'hi from ruby')
  sleep 0.1
end

# flush
OpenTelemetry.tracer_provider.shutdown
puts 'span flushed'
```

```bash
ruby test_trace.rb
```

---

## Step 6 — Verify in Grafana

Open Grafana → **Explore** → datasource: **Tempo** → "Search" tab → service: `test-ruby-app` (or your `OTEL_SERVICE_NAME`).

For Rails apps with auto-instrumentation, also check the **Traces Browser** dashboard — you'll see your service in the service graph alongside its database dependencies.

---

## Common pitfalls

- **Rails fork/preload (Spring, Bootsnap)** — if you use Spring or Bootsnap for fast Rails reloads, OTel may initialise once in the parent and not propagate to forks. Set `OTEL_RUBY_BSP_START_THREAD_ON_BOOT=false` and re-call `OpenTelemetry::SDK.configure` after fork in `config/puma.rb` or `config/unicorn.rb`.
- **Sidekiq workers** — auto-instrumentation works, but **each worker thread needs its own tracer context**. The Sidekiq instrumentation gem handles this automatically.
- **Self-signed certs in dev** — Ruby's Net::HTTP doesn't easily skip cert verification via env var. Either use a real Let's Encrypt cert, or set `OTEL_EXPORTER_OTLP_CERTIFICATE` to your Caddy cert PEM file path.
- **Traces missing for outgoing HTTP** — make sure you're requiring instrumentation *before* the gems they instrument. Rails initializers handle this automatically; for non-Rails apps put `require 'opentelemetry/instrumentation/all'` at the top of your entrypoint.
- **Missing trace IDs in Rails logs** — install `opentelemetry-instrumentation-rails` (included in `-all`) and configure the Rails log formatter to include `OpenTelemetry::Trace.current_span.context.hex_trace_id`.

---

## Next steps

- [Java instrumentation](java.md)
- [Python instrumentation](python.md)
- [Architecture overview](../architecture.md)
- [OpenTelemetry Ruby docs](https://opentelemetry.io/docs/languages/ruby/)
