# ADR 0004: No MinIO at Simple profile (filesystem storage)

**Status:** Accepted
**Date:** 2026-04-25

## Context

The original prototype used MinIO as a single shared S3-compatible object store, with separate buckets for Mimir, Loki, Tempo, and Pyroscope. This was modeled after how the LGTM stack scales horizontally — every backend writes blocks to S3, multiple replicas can read them.

On a single 4 GB VPS, this design has a real cost:

- MinIO **preallocates ~1 GB** at startup ([GitHub discussion #19133](https://github.com/minio/minio/discussions/19133)) — 25% of total RAM for zero benefit at single-node scale.
- Adds an extra service to fail, debug, and operate.
- Adds an init container (`init_buckets.sh`) to bootstrap buckets — more moving parts.
- All four backends already support **filesystem storage** as a first-class backend.

There is no realistic scenario at Simple profile where having S3 instead of filesystem improves anything. The benefits of object storage (decoupled scaling, multi-replica reads, tiered storage) only matter when you actually have multiple replicas or tiered tooling.

## Decision

**Drop MinIO from the Simple profile entirely.** All backends use filesystem storage with named Docker volumes.

| Backend | Storage path inside container | Volume |
|---------|-------------------------------|--------|
| Prometheus | `/prometheus` | `prometheus_data` |
| VictoriaLogs | `/vlogs` | `victorialogs_data` |
| Tempo | `/var/tempo` | `tempo_data` |
| Pyroscope | `/data` | `pyroscope_data` |

MinIO **returns** at the Scale profile (v2) when the operator actually has multiple nodes that need shared storage.

## Consequences

**Positive:**
- Saves **~1 GB of preallocated RAM** plus ~50 MB MinIO runtime. Phase 1 measured the entire stack at ~253 MB idle without MinIO.
- One fewer service to deploy, monitor, and debug.
- One fewer init container; bucket-bootstrap script deleted.
- Backups are simpler — `tar` over Docker volumes vs. `mc mirror` from MinIO buckets.

**Negative:**
- Migration to Scale profile requires a one-time data migration step (filesystem → S3). Documented in [Operations / Upgrade](../operations/upgrade.md). Not a concern for v1 users since Scale is a v2 release.
- Some optional features (cross-region replication, multi-tenancy via separate buckets) become unavailable at Simple. Acceptable trade-off — they're not Simple-profile concerns.

**Neutral:**
- Filesystem storage works identically to S3 from the application's perspective; query/write performance is comparable at single-node scale.

## References

- [MinIO 1 GiB preallocation discussion](https://github.com/minio/minio/discussions/19133)
- [Tempo filesystem backend docs](https://grafana.com/docs/tempo/latest/configuration/#local-storage-recommendations)
- [Mimir filesystem alternative (rmoff)](https://rmoff.net/2026/01/14/alternatives-to-minio-for-single-node-local-s3/)
- [Spec §4.1 — Stack selection](../superpowers/specs/2026-04-25-obstack-redesign.md)
