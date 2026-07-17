# Distributed Sharded Load Balancer

A distributed key-value store with consistent-hash load balancing, sharding, and primary/replica log replication. This is the active, consolidated project — earlier iterations (`Assignment1`, `Assignment2`, `Assignment3`) are preserved untouched under [`../legacy/`](../legacy/) for reference; this project started as a copy of `Assignment3`, the most complete of the three.

## Architecture

Three services, all on a shared Docker bridge network (`pub`):

- **Load balancer** (`load_balancer.py`, Flask, port 5000, the only service port-mapped to the host). Maintains an in-memory `ServerMap`/`ShardMap` and routes requests to servers using consistent hashing. Exposes:
  - `POST /init` — configure schema, shards, and servers; spawns the server containers
  - `GET /status` — current shard/server topology
  - `POST /add`, `DELETE /rm` — scale servers up/down
  - `GET /read`, `POST /write`, `PUT /update`, `DELETE /del` — data operations, fanned out across shards
  - `GET /read/<serverName>` — read directly from one server
  - There is intentionally no `/` route and no host-reachable `/heartbeat` — hitting either 404s by design (see "Health check" below).

- **Shard manager** (`shard_manager/shard_manager.py`, Flask, internal only — not port-mapped to the host). Tracks which servers hold which shards, runs a background loop every 15s that:
  - pings each server's `/heartbeat`,
  - runs primary election per shard (the replica with the highest WAL count wins),
  - if a server is unreachable, respawns its container and replays the primary's WAL into it via `/get_wal`.

- **Server** (`server/server.py` + `manager.py` + `helper.py`, one container per server instance, internal only). Built `FROM mysql:8.0-debian`; the Flask app is launched by `deploy.sh` via MySQL's `/always-initdb.d` init hook (see `server/Dockerfile`, `server/custom-entry.sh`). Exposes CRUD (`/read`, `/write`, `/update`, `/del`), replication (`/get_wal`, `/get_wal_count`), `/config`, `/copy`, and `/heartbeat`.

Server containers don't exist until `/init` (or `/add`) is called — the load balancer spawns them at runtime via the Docker CLI, using the host's `docker.sock` mounted into the `load_balancer` container.

## Prerequisites

- Docker + Docker Compose
- GNU Make

## Build & run

```bash
cd project
make all       # builds ds_server:latest, then `docker compose up -d` (load_balancer_1, shard_manager_1)
make clean     # tear down containers/images/network
make restart   # clean + all
```

## Verifying it's healthy

The load balancer's own routes are listed above — nothing else exists at the top level, so `curl localhost:5000/` and `curl localhost:5000/heartbeat` will 404 even when everything is working correctly. `/heartbeat` only exists on the per-shard `server` containers, which aren't reachable from the host (no port mapping) — only from inside the `pub` network.

Check the load balancer is up:

```bash
curl http://localhost:5000/status
# → {"servers":{},"shards":[]}   (200 OK; empty until /init has been called)
```

To bring up an actual cluster, `POST` a config to `/init` with your schema/shards/servers (see the handler in `load_balancer.py` for the exact payload shape), then re-check `/status` — it should reflect what you configured, and `docker ps` will show the newly spawned `ds_server` containers on the `pub` network.

## Repo layout

```
project/
├── Dockerfile, Makefile, docker-compose.yml   # load balancer build/orchestration
├── load_balancer.py                           # routing, consistent hashing, CRUD fan-out
├── server/                                    # per-shard server image (MySQL + Flask), WAL replication
├── shard_manager/                              # primary election, crash detection/recovery
└── analysis.ipynb / analysis.pdf / images/     # performance benchmarks from earlier iterations
```

## Roadmap

_Status as of 2026-07-17._ Terraform, Ansible, GitHub Actions CI/CD, and Prometheus/Grafana monitoring are planned but not yet built. This section will be updated to reflect each as it actually lands — not before.
