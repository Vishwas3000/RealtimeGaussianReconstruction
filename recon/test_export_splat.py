"""Tests for export_splat.py (numpy only). Run: python -m unittest discover -s recon"""
import unittest

import numpy as np

import export_splat as es


def unit(q):
    return q / np.linalg.norm(q, axis=-1, keepdims=True)


class ExportSplatTest(unittest.TestCase):
    def test_quaternion_helpers_agree_with_matrices(self):
        rng = np.random.default_rng(0)
        q1, q2 = unit(rng.normal(size=(2, 50, 4)))
        np.testing.assert_allclose(es.quat_to_rotmat(es.quat_mult(q1, q2)),
                                   es.quat_to_rotmat(q1) @ es.quat_to_rotmat(q2), atol=1e-9)
        np.testing.assert_allclose(es.quat_to_rotmat(es.FLIP_Q), es.FLIP, atol=1e-12)

    def test_records_round_trip(self):
        rng = np.random.default_rng(1)
        n = 1000
        means, log_scales, sh_dc = rng.normal(size=(3, n, 3)) * np.array([50, 1, 1])[:, None, None]
        quats, logits = rng.normal(size=(n, 4)), rng.normal(size=n) * 3
        rec = es.to_records(means, log_scales, quats, sh_dc, logits)
        self.assertEqual(len(rec.tobytes()), 32 * n)
        pos, scale, q, rgb, alpha = es.from_records(rec)
        opacity = 1 / (1 + np.exp(-logits))
        order = np.argsort(-(np.exp(log_scales).prod(axis=1) * opacity), kind="stable")
        np.testing.assert_allclose(pos, means[order], rtol=1e-6)
        np.testing.assert_allclose(scale, np.exp(log_scales[order]), rtol=1e-6)
        np.testing.assert_allclose(rgb, np.clip(0.5 + es.SH_C0 * sh_dc[order], 0, 1), atol=0.5 / 255 + 1e-9)
        np.testing.assert_allclose(alpha, opacity[order], atol=0.5 / 255 + 1e-9)
        angle = 2 * np.degrees(np.arccos(np.clip(np.abs((q * unit(quats[order])).sum(axis=1)), 0, 1)))
        self.assertLess(angle.max(), 3.0)  # 8-bit rotations stay within a few degrees

    def test_cars_are_posed_at_the_chosen_frame(self):
        half = np.radians(90) / 2
        about_y = [np.cos(half), 0, np.sin(half), 0]  # car 0 turned 90° about y
        models = {
            "Background": {"_means": np.zeros((1, 3)), "_scales": np.zeros((1, 3)), "_quats": np.array([[1.0, 0, 0, 0]]),
                           "_features_dc": np.zeros((1, 3)), "_opacities": np.zeros((1, 1))},
            "RigidNodes": {
                "_means": np.array([[1.0, 0, 0], [1.0, 0, 0]]), "_scales": np.zeros((2, 3)),
                "_quats": np.array([[1.0, 0, 0, 0]] * 2), "_features_dc": np.zeros((2, 3)),
                "_opacities": np.zeros((2, 1)), "points_ids": np.array([[0], [1]]),
                "instances_quats": np.array([[[1.0, 0, 0, 0], [1.0, 0, 0, 0]], [about_y, [1.0, 0, 0, 0]]]),
                "instances_trans": np.array([[[0.0, 0, 0], [0, 0, 0]], [[10.0, 0, 0], [0, 0, 0]]]),
                "instances_fv": np.array([[True, True], [True, False]]),  # car 1 is absent in frame 1
            },
        }
        means, _, quats, _, _ = es.scene_splats(models, frame=1)
        self.assertEqual(len(means), 2)  # background + car 0
        np.testing.assert_allclose(means[1], [10, 0, -1], atol=1e-9)  # (1,0,0) turned 90° about y, then moved
        np.testing.assert_allclose(es.quat_to_rotmat(quats[1]), es.quat_to_rotmat(np.array(about_y)), atol=1e-9)


if __name__ == "__main__":
    unittest.main()
