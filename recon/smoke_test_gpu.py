"""Check that torch and drivestudio's three compiled dependencies run on this GPU (sm_120)."""
import math

import torch


def check(name, fn):
    try:
        print(f"[ok]   {name}: {fn()}")
        return True
    except Exception as e:  # report every failure, not just the first
        print(f"[FAIL] {name}: {type(e).__name__}: {e}")
        return False


def torch_info():
    assert torch.cuda.is_available(), "CUDA not available"
    cap = torch.cuda.get_device_capability()
    arch = torch.cuda.get_arch_list()
    assert f"sm_{cap[0]}{cap[1]}" in arch, f"sm_{cap[0]}{cap[1]} not in {arch}"
    return f"torch {torch.__version__}, CUDA {torch.version.cuda}, {torch.cuda.get_device_name()} {cap}"


def gsplat_render():
    from gsplat.rendering import rasterization

    n, w, h = 2000, 320, 240
    g = torch.Generator(device="cuda").manual_seed(0)
    means = torch.randn(n, 3, device="cuda", generator=g) * 0.5 + torch.tensor([0.0, 0.0, 3.0], device="cuda")
    quats = torch.nn.functional.normalize(torch.randn(n, 4, device="cuda", generator=g), dim=-1)
    scales = torch.full((n, 3), 0.03, device="cuda")
    opacities = torch.full((n,), 0.8, device="cuda")
    colors = torch.rand(n, 3, device="cuda", generator=g)
    f = 0.5 * w / math.tan(math.radians(30))
    K = torch.tensor([[f, 0, w / 2], [0, f, h / 2], [0, 0, 1]], device="cuda")[None]
    viewmat = torch.eye(4, device="cuda")[None]
    _, alpha, _ = rasterization(means, quats, scales, opacities, colors, viewmat, K, w, h)
    covered = (alpha > 0.01).float().mean().item()
    assert covered > 0.05, f"only {covered:.1%} of pixels covered"
    return f"rendered {w}x{h}, {covered:.0%} of pixels covered"


def pytorch3d_knn():
    from pytorch3d.ops import knn_points

    p1 = torch.rand(1, 500, 3, device="cuda")
    p2 = torch.rand(1, 800, 3, device="cuda")
    d, idx, _ = knn_points(p1, p2, K=3)
    ref = torch.cdist(p1[0], p2[0]).topk(3, largest=False)
    assert torch.equal(idx[0], ref.indices), "knn indices differ from torch.cdist"
    assert torch.allclose(d[0], ref.values ** 2, atol=1e-5), "knn distances differ from torch.cdist"
    return "knn_points matches torch.cdist"


def nvdiffrast_cube():
    import nvdiffrast.torch as dr

    cube = torch.rand(1, 6, 64, 64, 3, device="cuda")
    dirs = torch.nn.functional.normalize(torch.randn(1, 32, 32, 3, device="cuda"), dim=-1)
    out = dr.texture(cube, dirs.contiguous(), filter_mode="linear", boundary_mode="cube")
    assert out.shape == (1, 32, 32, 3) and torch.isfinite(out).all()
    return "cube-map lookup ok"


if __name__ == "__main__":
    results = [check(n, f) for n, f in [("torch", torch_info), ("gsplat", gsplat_render),
                                         ("pytorch3d", pytorch3d_knn), ("nvdiffrast", nvdiffrast_cube)]]
    raise SystemExit(0 if all(results) else 1)
