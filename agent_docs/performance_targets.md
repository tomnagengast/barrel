# Performance Targets

## Typing Latency

| Metric | Target |
|---|---|
| Main thread time per edit (no preview) | < 1 ms |
| Preview update latency, p50 | < 16 ms |
| Preview update latency, p95 | < 50 ms |
| Large docs (10MB+) | Degrade gracefully, never block typing |

## File Open

| File size | Time to first paint |
|---|---|
| < 100 KB | < 100 ms |
| 1 MB | < 300 ms |
| 10 MB | < 1 s |
| 50 MB | < 3 s |

## Scrolling

- Preview scroll at 120 Hz on a large doc: no dropped frames
- Tiled rendering: only blocks in viewport + small overscan are drawn

## Memory

| Scenario | Target |
|---|---|
| Baseline (empty file) | < 30 MB |
| 1 MB file open | < 80 MB |
| 10 MB file open | < 200 MB |
| 50 MB file open | < 400 MB |

Memory should be roughly proportional to visible preview + block cache, not the full document.

## Instrumentation

### os_signpost spans (always present, zero-cost when not profiling)

- `editCapture` — main thread edit recording
- `dirtyExpand` — dirty range expansion to safe region
- `parse` — cmark parse of reparse region
- `blockDiff` — diff old vs new blocks
- `layout` — layout computation for changed blocks
- `previewApply` — main thread preview splice

### In-app perf HUD (opt-in)

Display:
- Current revision number
- Dirty range size (UTF-16 units)
- Reparse region size
- Parse time (ms)
- Layout time (ms)
- Apply time (ms)
- Number of blocks changed
- Total block count
- Cache hit rate

### Benchmark harness

`scripts/perf_smoke.sh` runs against fixtures and reports:
- Cold open time
- Full parse time
- Incremental parse time (simulated single-character edit)
- Memory high-water mark
