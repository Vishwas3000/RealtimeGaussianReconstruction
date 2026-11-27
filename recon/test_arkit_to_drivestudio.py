"""Tests for arkit_to_drivestudio.py (numpy and Pillow). Run: python -m unittest discover -s recon"""
import unittest

import numpy as np

import arkit_to_drivestudio as ad


class ArkitToDrivestudio(unittest.TestCase):
    def test_arkit_identity_pose_gives_opencv_camera(self):
        # RoadCapture stores q_WA * q_AC with q_AC = 180 deg about x (OdometryEncoder.swift). For ARKit's identity
        # pose the camera looks down world -z, so the OpenCV camera's z and y must map to world -z and -y.
        np.testing.assert_allclose(ad.quat_to_rotmat([1, 0, 0, 0]), np.diag([1, -1, -1]), atol=1e-12)

    def test_quaternion_order_is_xyzw(self):
        c, s = np.cos(np.pi / 8), np.sin(np.pi / 8)  # 45 deg about z
        np.testing.assert_allclose(ad.quat_to_rotmat([0, 0, s, c]) @ [1, 0, 0], [0.5 ** 0.5, 0.5 ** 0.5, 0], atol=1e-12)

    def test_depth_pixels_land_on_their_image_pixels(self):
        K = (2555.0, 2555.0, 1935.0, 1081.0)  # a 3840x2160 frame; its depth map is 256x144, 15 image pixels per depth pixel
        mask = np.zeros((144, 256), bool)
        mask[[0, 71, 143], [0, 128, 255]] = True
        p = ad.backproject(np.full((144, 256), 4.0), mask, ad.scale_intrinsics(K, 256 / 3840, 144 / 2160))
        u, v = p[:, 0] / p[:, 2] * K[0] + K[2], p[:, 1] / p[:, 2] * K[1] + K[3]
        np.testing.assert_allclose(u, [7, 128 * 15 + 7, 255 * 15 + 7], atol=1e-9)  # centre of depth pixel j: 15j + 7
        np.testing.assert_allclose(v, [7, 71 * 15 + 7, 143 * 15 + 7], atol=1e-9)
        np.testing.assert_allclose(p[:, 2], 4.0)

    def test_agreement_is_zero_for_a_consistent_wall(self):
        # A wall 5 m ahead seen from two poses 1 m apart along it: re-projected depths must match exactly.
        Kd = ad.scale_intrinsics((2555.0, 2555.0, 1935.0, 1081.0), 256 / 3840, 144 / 2160)
        depth, conf = np.full((144, 256), 5.0), np.full((144, 256), 2, np.uint8)
        poses = [np.eye(4), np.eye(4)]
        poses[1][0, 3] = 1.0
        pts = ad.backproject(depth, conf >= 2, Kd)
        err = ad.lidar_agreement([pts, pts], poses, [depth, depth], [conf, conf], [Kd, Kd], 2, 1)
        self.assertGreater(len(err), 1000)
        self.assertLess(err.max(), 1e-9)

    def test_redrawn_frame_keeps_each_ray_on_its_pixel(self):
        # Autofocus moves the focal length; a frame redrawn for K_out must show the same ray at each output pixel.
        K_frame, K_out = (1100.0, 1080.0, 801.0, 449.0), (1050.0, 1040.0, 799.5, 451.0)
        a, _, c, _, e, f = ad.resample_coeffs(K_frame, K_out)
        u, v = 100.0, 700.0  # an output pixel; Pillow samples the input at (a(u+.5)+c, e(v+.5)+f) with +.5 centres
        self.assertAlmostEqual(a * (u + 0.5) + c - 0.5, K_frame[0] * (u - K_out[2]) / K_out[0] + K_frame[2])
        self.assertAlmostEqual(e * (v + 0.5) + f - 0.5, K_frame[1] * (v - K_out[3]) / K_out[1] + K_frame[3])

    def test_shared_camera_fits_inside_every_frame(self):
        Ks = np.array([[1000, 1000, 800, 450], [1060, 1060, 803, 448], [990, 990, 797, 452]], float)
        K_out = ad.shared_intrinsics(Ks, 1600, 900)
        for K in Ks:
            a, _, c, _, e, f = ad.resample_coeffs(K, K_out)
            for x in (0, 1600):  # output edges, in Pillow's coordinates, must sample inside the input frame
                self.assertTrue(-1e-9 <= a * x + c <= 1600 + 1e-9)
            for y in (0, 900):
                self.assertTrue(-1e-9 <= e * y + f <= 900 + 1e-9)


if __name__ == "__main__":
    unittest.main()
