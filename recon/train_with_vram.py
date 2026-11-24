"""Run drivestudio's tools/train.py unchanged and report peak GPU memory and wall time on exit (also after an OOM).

Run from the drivestudio checkout with PYTHONPATH set to it, passing train.py's own arguments:
  python <repo>/recon/train_with_vram.py --config_file ... --output_root ... key=value ...
"""
import atexit
import runpy
import sys
import time

import torch

start = time.time()


def report():
    if not torch.cuda.is_available():
        return
    gb = 1024 ** 3
    total = torch.cuda.get_device_properties(0).total_memory / gb
    print(f"[vram] peak allocated {torch.cuda.max_memory_allocated() / gb:.2f} GB, "
          f"peak reserved {torch.cuda.max_memory_reserved() / gb:.2f} GB of {total:.2f} GB; "
          f"wall time {time.time() - start:.0f} s", flush=True)


atexit.register(report)
sys.argv = ["tools/train.py", *sys.argv[1:]]
runpy.run_path("tools/train.py", run_name="__main__")
