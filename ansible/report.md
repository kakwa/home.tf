# Slow sleep/wake on `laphroaig` (`ai.local`) — root cause report

**Host:** `root@ai.local` · hostname `laphroaig` · Debian 14 · kernel `7.2.15+deb14-amd64`
**GPU:** AMD Navi 31 (Radeon RX 7900 XT/XTX/GRE/M) @ `0000:03:00.0`, KFD via `/dev/kfd`
**Boot under analysis:** Fri 2026-11-06 01:24:06 (no reboot after the event)

---

## 1. Executive summary

The "6–8 minute slow wake-up" was **not a slow wake-up**. The machine got **stuck in the *suspend* phase for ~8 minutes**, then entered S1 and woke up almost instantly.

- **What actually took the minutes:** the amdgpu/KFD **suspend** path. `llama-server` (ROCm/KFD inference) was actively generating tokens on the RX 7900 XT and pinning **~16 GB of GPU buffers that are also backed by system RAM** (shmem). With 31 GB of RAM already nearly full (~359 MB free), the driver's attempt to **back up the KFD GPU address space to system RAM** thrashed on memory reclaim for ~8 minutes.
- **The "scary" `dmesg` trace is a symptom, not the cause.** On resume, restoring that process's buffers **failed with an OOM** (`order:0`, `GFP_NOIO` allocation failure). The driver gave up on KFD process **pid 768**; its deferred teardown ran ~5 minutes later and hit a kernel `WARNING` in `amdgpu_bo_free_kernel`.
- **Net effect:** the inference process was killed by the suspend/resume cycle. The kernel warning is a real amdgpu KFD edge-case, but here it is *downstream* of the memory exhaustion, not an independent hardware/driver fault.

---

## 2. Timeline (`journalctl -b 0 -k`)

| Time (2026-11-06) | Phase | What happened |
|---|---|---|
| **01:24:06** | boot | System boots. |
| **01:43:00–08** | pre-sleep | `llama-server[768]` actively inferring (task 765, ~44 tok/s, ~16 GB GPU buffers). |
| **01:43:30** | **SUSPEND ENTRY** | `PM: suspend entry (shallow)` + `Filesystems sync: 0.006 seconds` (470 log lines in this second — fast). |
| **01:43:30 → 01:51:28** | **THE 8-MIN STALL** | **~7 min 57 s of total kernel silence** (0–1 log lines). PM core is in the **device-suspend** phase — specifically amdgpu quiescing the busy GPU and saving the ~16 GB KFD address space to (nearly empty) system RAM. |
| **01:51:28** | freeze | `Freezing user space processes … completed (elapsed 0.001 s)` then `Freezing remaining freezable tasks … completed (0.001 s)` — **fast**. |
| **01:51:28** | **ENTER S1 + IMMEDIATE WAKE** | `ACPI: PM: Preparing to enter system sleep state S1` → immediately `ACPI: PM: Waking up from system sleep state S1` → `Restarting tasks: Done` → `PM: suspend exit`. The S1 dwell was **< 1 s**. |
| **01:51:28** | **RESUME FAILURE** | During async resume of amdgpu: `page allocation failure: order:0, mode:0x100c02(GFP_NOIO\|__GFP_HIGHMEM\|__GFP_HARDWALL)` in `kworker/u16:16 (Workqueue: async)`. → `amdgpu: Restore process pid 768 failed during resume` → `amdgpu 0000:03:00.0: PM: dpm_run_callback(): pci_pm_resume returns -14` (EFAULT) → `PM: failed to resume async: error -14`. |
| **01:56:29** | **DEFERRED KFD TEARDOWN (the WARNING)** | ~5 min later, the abandoned KFD process is torn down on the async workqueue: `WARNING: … amdgpu_object.c:512 at amdgpu_bo_free_kernel+0x132/0x150 [amdgpu], CPU#3: kworker/u16:16/1134`, with the trace through `kfd_process_destroy_pdds` → `kfd_process_wq_release`. |

**Key takeaway from the timeline:** the minutes were spent **before** the machine ever entered sleep (between `Filesystems sync` at 01:43:30 and `Freezing` at 01:51:28). The actual sleep→wake transition at 01:51:28 was **instantaneous**.

---

## 3. Phase-by-phase breakdown

### 3.1 Suspend entry + filesystem sync (01:43:30) — fast
`PM: suspend entry (shallow)` and `Filesystems sync: 0.006 seconds` both land in the same second. Nothing wrong here.

### 3.2 The 8-minute stall (01:43:30 → 01:51:28) — device suspend
The PM core's next step after filesystem sync is **suspending the devices** (`dpm_suspend_start`). For an amdgpu device with an active KFD client, this requires:
1. **Quiescing the GPU** — waiting for in-flight work/fences to drain. `llama-server[768]` was mid-inference at ~44 tok/s when sleep was triggered.
2. **Saving the KFD GPU address space to system RAM** — the driver must migrate the process's ~16 GB of GPU buffers (backed by shmem) into system memory so they can be restored on resume.

With only **~359 MB of RAM free** (31 GB total, ~16 GB shmem + ~15 GB inactive_anon already committed), step 2 had no headroom. The kernel **thrashed on page reclaim / swap** for ~8 minutes trying to find room for the backup. The silence in the logs is this reclaim loop — no PM log lines are emitted until the device-suspend callback finally returns.

> Note: we cannot fully separate "fence drain" from "save-thrash" in the logs alone, but the memory numbers and the identical OOM on resume make **save-thrash under memory pressure** the dominant factor.

### 3.3 Freeze + S1 + immediate wake (01:51:28) — instant
`Freezing user space processes completed (0.001 s)`, `Preparing to enter system sleep state S1`, then **immediately** `Waking up from system sleep state S1`. The S1 dwell was under a second — consistent with the manual "sleep then wake immediately" trigger.

### 3.4 Resume + amdgpu/KFD restore failure (01:51:28) — OOM
On resume the async workqueue (`kworker/u16:16`) runs amdgpu's resume callback, which tries to **restore process 768's GPU buffers** back from system memory into VRAM/GPU:

```
page allocation failure: order:0, mode:0x100c02(GFP_NOIO|__GFP_HIGHMEM|__GFP_HARDWALL)
  CPU: kworker/u16:16  (Workqueue: async)
  Call Trace:
   __ttm_pool_alloc [ttm]
   amdgpu_ttm_tt_populate
   ttm_bo_bounce_temp_buffer
   ttm_bo_validate
   amdgpu_amdkfd_bo_validate
   amdgpu_amdkfd_gpuvm_restore_process_bos
   restore_process_helper
   dpm_run_callback            # async resume of amdgpu
  amdgpu: Restore process pid 768 failed during resume
  amdgpu 0000:03:00.0: PM: dpm_run_callback(): pci_pm_resume returns -14
  amdgpu 0000:03:00.0: PM: failed to resume async: error -14
```

The TTM pool could not allocate even a single **order-0** page with `GFP_NOIO` (required during resume). Result: process restore fails, `pci_pm_resume` returns `-14` (`EFAULT`), and the driver **abandons KFD process pid 768**.

### 3.5 Deferred KFD teardown WARNING (01:56:29) — the dmesg trace
Because the restore failed, KFD must tear the process down. That happens **asynchronously on a workqueue**, ~5 minutes later:

```
WARNING: drivers/gpu/drm/amd/amdgpu/amdgpu_object.c:512
         at amdgpu_bo_free_kernel+0x132/0x150 [amdgpu], CPU#3: kworker/u16:16/1134
  … via kfd_process_destroy_pdds → kfd_process_wq_release → process_one_work → worker_thread
```

This `WARNING` fires inside the buffer-free path while freeing buffers that were left in an **inconsistent state** by the failed restore. It is the *consequence* of the OOM'd restore, not a separate fault.

---

## 4. Root-cause chain

1. `llama-server` (pid 768) is running inference on the RX 7900 XT, pinning **~16 GB of GPU buffers** that are shmem-backed and therefore also counted against **system RAM**.
2. System RAM (31 GB) is effectively full: ~16 GB shmem + ~15 GB inactive_anon → **~359 MB free**.
3. User triggers sleep at 01:43:30.
4. PM core reaches **device suspend**; amdgpu must quiesce the busy GPU and **save the ~16 GB KFD address space to system RAM**.
5. With no RAM headroom, that save **thrashes on reclaim for ~8 minutes** (the log silence, 01:43:30 → 01:51:28). ← **this is "what took the minutes"**
6. The stall clears; PM freezes tasks (0.001 s), enters **S1**, and wakes immediately.
7. On **resume**, restoring process 768's buffers hits an **OOM** (`order:0 GFP_NOIO` fails) → `Restore process pid 768 failed` → `pci_pm_resume returns -14` (EFAULT).
8. The driver **abandons pid 768**; its **deferred KFD teardown** runs ~5 min later (01:56:29) and emits the **`amdgpu_bo_free_kernel` WARNING**.

---

## 5. Memory evidence

`Mem-Info` at the point of failure (resume OOM):

| Counter | Value | ~Size |
|---|---|---|
| `gpu_active` | 16 229 828 kB | ~15.5 GB (pinned in GPU buffers) |
| `inactive_anon` | 15 545 896 kB | ~14.8 GB |
| `shmem` | 15 371 540 kB | ~14.7 GB (ROCm/llama shmem-backed buffers) |
| `free` | 91 996 pages | **~359 MB free** |

State *now* (post-event, `free -h`):

```
               total        used        free      shared  buff/cache   available
Mem:            31Gi       8.1Gi       6.8Gi       684Ki        16Gi        23Gi
Swap:           31Gi        16Mi        31Gi
```

Current `llama-server` (new instance, **pid 1277**, the old pid 768 is dead): RSS ≈ 8 GB, VSZ ≈ 36 GB.

---

## 6. Why the dmesg trace is "concerning" — and how much to worry

- It **is** a genuine kernel `WARNING` in amdgpu's buffer-free path (`amdgpu_bo_free_kernel`), reached through KFD's deferred process-destruction workqueue (`kfd_process_destroy_pdds` / `kfd_process_wq_release`). That code path is a known-fragile area of the amdgpu KFD **suspend/resume** handling.
- But **here it is a symptom**: it only fired *because* the restore OOM'd and left buffers in a bad state. It did not take the box down (no panic/oops, no reboot — `uptime -s` still 01:24:06).
- **Practical impact:** the GPU inference process was **killed** by the sleep cycle. If you had unflushed work, it's gone.
- **Underlying risk:** any suspend/resume while a large KFD workload is resident on a memory-constrained box will (a) hang for minutes and (b) very likely kill the workload. The warning is the visible tip of that.

---

## 7. Recommendations

**Immediate / operational**
- **(a) Stop or quiesce `llama-server` before sleeping.** Freeing the ~16 GB of GPU/shmem buffers removes both the 8-min thrash and the resume OOM. This is the single most effective fix.
- **(b) Add RAM headroom or shrink the workload.** 31 GB is not enough to hold ~16 GB of GPU buffers *plus* their shmem/system-RAM shadow *plus* the OS. Either add RAM, use a smaller model/context, or reduce `--ctx-size` / GPU offload so the footprint leaves real headroom.

**Configuration**
- **(c) Review amdgpu module parameters** on this host: `timeout_period`, `cwsr_enable`, `runpm`, `gpu_recovery`. (Verify current values before changing.)
- **(d) Consider the sleep state.** Note this was **S1 (shallow)** — even shallow sleep runs the full amdgpu/KFD save+restore, so switching to a deeper state (S3) is unlikely to help by itself; the memory pressure is the driver of the failure.

**Hardening**
- **(e) Add a suspend watchdog / timeout** so a stuck suspend self-aborts instead of hanging ~8 minutes.
- **(f) Update the kernel + ROCm/amdgpu stack** — the KFD suspend/resume + deferred-teardown path has had fixes upstream.

**Verification**
- **(g) Check for prior occurrences:** `journalctl -b -1 -k | grep -iE "page allocation failure|Restore process|pci_pm_resume|amdgpu_bo_free"` (and earlier boots) to see how often this has happened.
- **(h) Controlled re-test** (optional): with `llama-server` stopped, trigger a clean sleep/wake and confirm it completes in seconds with no warning — isolates the workload as the cause.

---

## 8. Key commands that produced the findings

```bash
# Timeline + silence gap
journalctl -b 0 -k | grep -iE "suspend entry|suspend exit|Freezing|Preparing to enter|Waking up|Filesystems sync"
# Per-30s log-bucket count (proves the ~8-min silence)
journalctl -b 0 -k --since "2026-11-06 01:43:00" --until "2026-11-06 01:52:00" | \
  awk '{print strftime("%H:%M", $2)}' | uniq -c
# Suspend/resume + amdgpu/KFD events
journalctl -b 0 -g "suspend|resume|PM:|amdgpu|kfd|Restore process|page allocation"
# GPU + KFD process holding the device
for d in /proc/[0-9]*; do ls -l $d/fd 2>/dev/null | grep -qE "kfd|renderD" && echo "$(basename $d) $(cat $d/comm)"; done
# Memory state
free -h; journalctl -b 0 -k | grep -A40 "Mem-Info"
```
