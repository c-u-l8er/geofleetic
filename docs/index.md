# GeoFleetic Documentation

> **The fleet that learns where. Spatial digital twins, federated route learning, and GNN optimization for geo-distributed intelligence.**

> **Part of the [&] Protocol stack** · [Ecosystem overview](../../ECOSYSTEM.md) · [Three-protocol stack](../../PULSE/docs/THREE_PROTOCOL_STACK.md) · [Stack status](../../STACK_COMPLETION.md)

Welcome to the documentation hub for **GeoFleetic** — the spatial intelligence
layer of the [&] Protocol ecosystem. GeoFleetic provides geo-distributed fleet
tracking, federated route learning, and GNN-based route optimization — all running
on the BEAM for fault tolerance and real-time concurrency.

GeoFleetic is the `&space` primitive provider, exposing `&space.fleet`,
`&space.route`, and `&space.geofence` capability contracts to the rest of the
[&] stack.

---

## The Problem

Fleet management systems today are centralized, batch-oriented, and privacy-hostile.
A logistics company with 10,000 vehicles streams all GPS data to a cloud API, which
returns routes computed on stale models. The fleet learns nothing from yesterday's
deliveries. Privacy regulations (GDPR, CCPA) make centralizing raw location data
increasingly untenable. And when the cloud API goes down, the fleet goes blind.

GeoFleetic provides spatial intelligence that:
- **Lives at the edge** — each vehicle reasons locally with sub-second latency
- **Learns continually** — routes improve from every delivery, not quarterly retraining
- **Preserves privacy** — shares model updates, never raw trajectories
- **Tolerates partitions** — vehicles operate offline and reconcile when reconnected
- **Composes with other intelligence** — spatial context enriches upstream reasoning

---

## Documentation Map


```{toctree}
:maxdepth: 1
:caption: Homepages

[&] Ampersand Box <https://ampersandboxdesign.com>
Graphonomous <https://graphonomous.com>
BendScript <https://bendscript.com>
WebHost.Systems <https://webhost.systems>
Agentelic <https://agentelic.com>
AgenTroMatic <https://agentromatic.com>
Delegatic <https://delegatic.com>
Deliberatic <https://deliberatic.com>
FleetPrompt <https://fleetprompt.com>
GeoFleetic <https://geofleetic.com>
OpenSentience <https://opensentience.org>
SpecPrompt <https://specprompt.com>
TickTickClock <https://ticktickclock.com>
```

```{toctree}
:maxdepth: 1
:caption: Root Docs

[&] Protocol Docs <https://docs.ampersandboxdesign.com>
Graphonomous Docs <https://docs.graphonomous.com>
BendScript Docs <https://docs.bendscript.com>
WebHost.Systems Docs <https://docs.webhost.systems>
Agentelic Docs <https://docs.agentelic.com>
AgenTroMatic Docs <https://docs.agentromatic.com>
Delegatic Docs <https://docs.delegatic.com>
Deliberatic Docs <https://docs.deliberatic.com>
FleetPrompt Docs <https://docs.fleetprompt.com>
GeoFleetic Docs <https://docs.geofleetic.com>
OpenSentience Docs <https://docs.opensentience.org>
SpecPrompt Docs <https://docs.specprompt.com>
TickTickClock Docs <https://docs.ticktickclock.com>
```

```{toctree}
:maxdepth: 2
:caption: GeoFleetic Docs

spec/README
```

---

## [&] Capability Contracts

| Capability | Operations | Description |
|-----------|------------|-------------|
| `&space.fleet` | locate, enrich, capacity, route | Fleet tracking and spatial digital twins |
| `&space.route` | route, optimize, explain | GNN-based route learning and optimization |
| `&space.geofence` | contains, enter_exit, enrich | Dynamic geofence boundary evaluation |

---

## Key Technologies

- **Spatial digital twins** — delta-CRDT-backed replicas that converge under partition
- **Federated learning** — LoRA adapter deltas shared across fleet, raw GPS stays on-device
- **GNN route optimization** — graph neural network continual learning for route quality
- **Multi-timescale memory** — edge SQLite + sqlite-vec, fleet-level PostGIS + Tile38
- **MCP + A2A protocols** — all capabilities exposed as MCP tools

---

## Architecture at a Glance

| Component | Role | OTP Pattern |
|-----------|------|-------------|
| **Fleet Tracker** | Delta-CRDT spatial digital twins | GenServer per asset |
| **Route Optimizer** | GNN-based continual route learning | GenServer + Nx |
| **Geofence Engine** | Tile38-inspired boundary evaluation | Concurrent tasks |
| **Federated Coordinator** | LoRA delta aggregation, privacy budgets | GenServer |
| **Fleet Dashboard** | Maps, routes, geofences, capacity heatmaps | Phoenix LiveView |

---

## Paired With

| Product | Relationship |
|---------|-------------|
| **TickTickClock** | Temporal intelligence — when + where = complete situational awareness |
| **Graphonomous** | Continual learning substrate for fleet knowledge |
| **Delegatic** | Governance enforcement for fleet operations |

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Elixir 1.17+ |
| Framework | Phoenix 1.8+ |
| Database | PostgreSQL 16+ + PostGIS |
| Spatial Index | Tile38 (or equivalent) |
| Edge Storage | SQLite + sqlite-vec |
| ML | Bumblebee / Nx (GNN, LoRA) |
| Replication | Epoch-aware delta-CRDTs |

---

## Project Links

- **Spec:** [Technical Specification](spec/README.md)
- **[&] Protocol ecosystem:** `AmpersandBoxDesign/`

---

*[&] Ampersand Box Design — geofleetic.com*
