hpdcache_tb quick notes

This is a minimal, non-exhaustive testbench to help observe the `hpdcache` top behavior with a simple memory model and a single requester. It aims for a naive write-through feel by setting `cfg_default_wb=0` and disabling any write coalescing.

What you still need to do
- Point your simulator to the cv-hpdcache RTL sources and includes (e.g., `hpdcache_pkg.sv`, `hpdcache_typedef.svh`, and all referenced modules). This TB just instantiates `hpdcache`.
- Set a real `hpdcache_cfg_t` for `TB_CFG` in `hpdcache_tb.sv`. The placeholder is `'0`. Pick a small config with `wtEn=1` and `wbEn=0` for naive WT.
- Fill the TODO fields for `hpdcache_req_t` and `hpdcache_rsp_t` if the simulator complains. Field names can vary depending on the exact package version.
- If `hpdcache` requires `HPDCACHE_OPENPITON` or other defines off, keep them off unless you need them.

Suggested compile lines (Questa/ModelSim)

Adjust the paths to match your local checkout.

```powershell
# From the workspace root or wherever you compile
vlib work
vlog +acc \
  +define+HPDCACHE_ASSERT_OFF \
  +incdir+path\to\cv-hpdcache\rtl\include \
  path\to\cv-hpdcache\rtl\src\hpdcache_pkg.sv \
  path\to\cv-hpdcache\rtl\src\*.sv \
  .\hardware\tb\hpdcache_tb.sv

vsim -c work.hpdcache_tb -do "run -all; quit" | tee sim.log
```

Suggested compile lines (Verilator)

```powershell
verilator --cc --exe --build \
  -Wall -Wno-fatal -Wno-DECLFILENAME \
  -Ipath\to\cv-hpdcache\rtl\include \
  path\to\cv-hpdcache\rtl\src\hpdcache_pkg.sv \
  path\to\cv-hpdcache\rtl\src\*.sv \
  .\hardware\tb\hpdcache_tb.sv
```

Notes
- The TB uses a very simple memory model: always-ready requests, fixed-latency read responses, and immediate write acks. Enhance if you need realistic ID handling or data return.
- The TB prints any core responses (`core_rsp_valid[0]`). You can add waveform dumping or more instrumentation as desired.
- For write-through without a write buffer, keep `cfg_default_wb=0`. The internal presence of a write buffer is architectural; at the top level we discourage coalescing via config which makes behavior close to naive WT.
