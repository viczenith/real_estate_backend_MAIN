# Multi-tenancy (SaaS) Readiness Plan

This document outlines a safe, incremental approach to evolve the AdminSupport app into a SaaS with multi-tenancy without breaking the existing monolith.

## Goals
- Preserve current single-tenant behavior (Estate project monolith) while enabling a future SaaS path.
- Avoid code churn until you opt-in; provide a clear checklist and migration path.

## Architecture overview
- Control plane (shared DB): tenants, domains/subdomains, billing/plans, feature flags, and (optionally) BYODB connection details.
- Data plane (per-tenant data): isolation by plan tier
  - Starter: shared DB + tenant_id filtering.
  - Pro: shared DB + schema per tenant (e.g., django-tenants + Postgres schemas).
  - Enterprise: database per tenant (managed by you or BYODB), via DB router.

## Phased rollout plan

1. Preparation (no behavior change)
- Add a `tenant_id` field to tenant-owned models (nullable), default to a single implicit tenant.
- Introduce a `current_tenant` context util; do not enforce filtering yet.
- Create a Tenant model (inactive) and a simple domain-to-tenant resolver middleware behind a feature flag.

2. Opt-in tenant scoping (shared schema)
- Enable default manager filtering by `current_tenant` only when a feature flag is enabled.
- Add a safe migration to backfill existing rows with the default tenant.
- Update background tasks, cache, media prefixes to be tenant-aware (prefix only; still single tenant in prod until flag on).

3. Advanced isolation options
- Schema-per-tenant: integrate `django-tenants` for Postgres; split apps into shared vs tenant apps.
- DB-per-tenant/BYODB: implement a database router and onboarding flow to test/seed a tenant database and run migrations.

4. Operational hardening
- Backups & DR for control plane; document shared responsibility for BYODB.
- Observability: tenant-aware logs/metrics; rate limiting per tenant.
- Feature flags and plan-based entitlements.

## Readiness checklist
- [ ] Inventory tenant-owned models and add `tenant_id` (nullable) + indexes
- [ ] Add `Tenant` and `Domain` models (inactive)
- [ ] Add `current_tenant` utility and a feature-flagged resolver middleware
- [ ] Default manager enforcing tenant filtering (flagged)
- [ ] Tenant-aware cache keys and media paths
- [ ] Background tasks accept tenant key and set context on run
- [ ] Management command: `migrate_tenants` (no-op until multi-tenant enabled)
- [ ] Security: encrypt any per-tenant secrets
- [ ] Docs: onboarding (connection test, seed, migrate), rollback

## BYODB onboarding sketch
- Collect DB creds; test connection; run migrations against tenant DB; seed data; verify health; store creds encrypted; activate tenant.

## Risk notes
- Connection limits when many tenant DBs are used → use pooling, close per-request.
- Per-tenant migrations must be idempotent and observable.

This doc is intentionally light-touch: it gives us a blueprint without modifying runtime code today. When you’re ready, we’ll turn items into code guarded by feature flags.
