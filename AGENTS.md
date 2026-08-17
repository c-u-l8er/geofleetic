# GeoFleetic — Agent Interface

> **Nothing below is callable.** These are *declarations*: three capability
> contracts and their operations, as JSON in `records/contracts/` and as tables
> in `docs/spec/README.md` §8. There is no server, no MCP endpoint and no
> implementation — `build-site.mjs` recounts the implementation at zero lines on
> every build. "Transport: MCP v1" states what the contracts declare, not
> something a client can connect to.

GeoFleetic is the spatial intelligence layer for the [&] Protocol ecosystem. It provides `&space` capabilities to AI agents.

## Capabilities

### &space.fleet
- `locate` — resolve current fleet/asset locations
- `enrich` — attach spatial context to upstream artifacts
- `capacity` — return region/fleet capacity snapshots
- `route` — produce fleet-aware route recommendations

### &space.route
- `route` — generate feasible route plans from origin/destination/constraints
- `optimize` — improve existing routes for efficiency, cost, or SLOs
- `explain` — explain route selection and tradeoffs for auditing

### &space.geofence
- `contains` — evaluate location membership in geofence boundaries
- `enter_exit` — detect boundary crossing events for tracked assets
- `enrich` — attach geofence/compliance context to upstream artifacts

## Protocol Integration

- Accepts from: `&memory.*`, `&time.*`, raw data, context
- Feeds into: `&reason.*`, `&memory.*`, output
- A2A skills: fleet-state-enrichment, regional-capacity-lookup, route-feasibility-evaluation, route-generation, route-optimization, geofence-membership-evaluation, boundary-alerting
- Transport: MCP v1 (Streamable HTTP)

## Status

`spec` rung. The document exists and its operation tables agree with the
contract files; that is the whole of it. The spec's own Pre-Phase — FV-1
through FV-4, the four experiments that would say whether any of this is
buildable — has not been started, and every task box in the roadmap is unticked.
See `docs/spec/README.md`, and the status block on the landing page.
