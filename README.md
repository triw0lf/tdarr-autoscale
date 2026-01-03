# Tdarr Autoscale

Automatically scale Tdarr workers based on Plex activity. Reduces workers when people are streaming to prioritize Plex, scales back up when idle.

## Features

- Scales workers based on active Plex streams
- Day/Night mode with different worker limits
- Auto-detects Tdarr node ID
- Works with Tautulli OR direct Plex API
- Supports GPU, CPU, or both worker types

## Requirements

- Tdarr
- Plex (with Tautulli recommended)
- `curl` and `jq`

## Installation

1. Download the script
2. Make executable: `chmod +x tdarr-autoscale.sh`
3. Edit the configuration variables at the top
4. Test: `./tdarr-autoscale.sh`
5. Add to cron:
```
crontab -e
*/5 * * * * /path/to/tdarr-autoscale.sh >> /path/to/tdarr-autoscale.log 2>&1
```

6. Optional - log rotation (clears log weekly):
```
0 0 * * 0 > /path/to/tdarr-autoscale.log
```

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `WORKER_TYPE` | `GPU` | Worker type: `GPU`, `CPU`, or `BOTH` |
| `USE_TAUTULLI` | `true` | Use Tautulli API (set `false` for direct Plex) |
| `WORKERS_IDLE` | `3` | Workers when no one is watching |
| `WORKERS_ACTIVE` | `1` | Workers when someone is streaming |
| `WORKERS_NIGHT` | `4` | Workers at night (idle) |
| `WORKERS_NIGHT_ACTIVE` | `2` | Workers at night (streaming) |
| `NIGHT_START` | `0` | Night mode start hour (24h) |
| `NIGHT_END` | `5` | Night mode end hour (24h) |

## Log Output

**GPU only:**
```bash
[2026-01-02 19:15:00] Streams: 0 | Mode: Day | GPU Workers: 3 (no change)
[2026-01-02 19:20:00] Streams: 1 | Mode: Day | GPU Workers: 1 (-2)
[2026-01-02 19:25:00] Streams: 0 | Mode: Day | GPU Workers: 3 (+2)
```

**CPU only:**
```bash
[2026-01-02 19:15:00] Streams: 0 | Mode: Day | CPU Workers: 3 (no change)
[2026-01-02 19:20:00] Streams: 1 | Mode: Day | CPU Workers: 1 (-2)
[2026-01-02 19:25:00] Streams: 0 | Mode: Day | CPU Workers: 3 (+2)
```

**Both GPU and CPU:**
```bash
[2026-01-02 19:15:00] Streams: 0 | Mode: Day | GPU Workers: 3 (no change) | CPU Workers: 3 (+1)
[2026-01-02 19:20:00] Streams: 1 | Mode: Day | GPU Workers: 1 (-2) | CPU Workers: 1 (-2)
```

## License

MIT

---

[![Built with Claude](https://img.shields.io/badge/Built%20with%20%E2%9D%A4%EF%B8%8F-Claude-blueviolet)](https://claude.ai)
