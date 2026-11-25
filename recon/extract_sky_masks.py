"""Sky masks for drivestudio-processed scenes, without mmcv.

drivestudio's own tool (datasets/tools/extract_masks.py) runs SegFormer-B5 Cityscapes through mmcv-full 1.2.7, which
needs torch 1.8 and has no kernels for the RTX 5070 Ti (sm_120). This runs the same model family through Hugging Face
transformers on current PyTorch and writes the same output: sky_masks/{image stem}.png, uint8 0/255, Cityscapes class
10 ("sky").

Run inside the drivestudio venv:
  python recon/extract_sky_masks.py --data_root ~/drivestudio/data/nuscenes/processed_10Hz/mini
"""
import argparse
from pathlib import Path

import numpy as np
import torch
import torch.nn.functional as F
from PIL import Image
from transformers import SegformerForSemanticSegmentation, SegformerImageProcessor

MODEL = "nvidia/segformer-b5-finetuned-cityscapes-1024-1024"
SKY = 10


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--data_root", type=Path, required=True, help="folder holding the scene folders (001, 002, ...)")
    ap.add_argument("--scenes", nargs="*", help="scene folder names (default: all)")
    ap.add_argument("--scale", type=float, default=0.5,
                    help="inference resolution relative to the image; masks are saved at full image size")
    ap.add_argument("--batch", type=int, default=6)
    ap.add_argument("--overwrite", action="store_true")
    args = ap.parse_args()

    processor = SegformerImageProcessor.from_pretrained(MODEL)
    model = SegformerForSemanticSegmentation.from_pretrained(MODEL).cuda().eval().half()
    if model.config.id2label[SKY] != "sky":
        raise SystemExit(f"class {SKY} is {model.config.id2label[SKY]!r}, not 'sky'")

    scenes = sorted(p for p in args.data_root.iterdir() if p.is_dir() and (not args.scenes or p.name in args.scenes))
    for scene in scenes:
        images = sorted((scene / "images").glob("*.jpg"))
        out_dir = scene / "sky_masks"
        out_dir.mkdir(exist_ok=True)
        todo = [p for p in images if args.overwrite or not (out_dir / f"{p.stem}.png").exists()]
        for start in range(0, len(todo), args.batch):
            paths = todo[start:start + args.batch]
            imgs = [Image.open(p).convert("RGB") for p in paths]
            w, h = imgs[0].size
            size = {"height": round(h * args.scale), "width": round(w * args.scale)}
            inputs = processor(images=imgs, size=size, return_tensors="pt")
            with torch.inference_mode():
                logits = model(pixel_values=inputs["pixel_values"].cuda().half()).logits
                logits = F.interpolate(logits.float(), size=(h, w), mode="bilinear", align_corners=False)
                sky = (logits.argmax(dim=1) == SKY).cpu().numpy()
            for p, mask in zip(paths, sky):
                Image.fromarray(mask.astype(np.uint8) * 255).save(out_dir / f"{p.stem}.png")
        print(f"{scene.name}: {len(images)} images, {len(todo)} new sky masks")


if __name__ == "__main__":
    main()
