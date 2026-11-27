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
        p = ad.backproject(np.full((144, 256), 4.0), mask, ad.depth_intrinsics(K, 3840, 256))
        u, v = p[:, 0] / p[:, 2] * K[0] + K[2], p[:, 1] / p[:, 2] * K[1] + K[3]
        np.testing.assert_allclose(u, [7, 128 * 15 + 7, 255 * 15 + 7], atol=1e-9)  # centre of depth pixel j: 15j + 7
        np.testing.assert_allclose(v, [7, 71 * 15 + 7, 143 * 15 + 7], atol=1e-9)
        np.testing.assert_allclose(p[:, 2], 4.0)

    def test_agreement_is_zero_for_a_consistent_wall(self):
        # A wall 5 m ahead seen from two poses 1 m apart along it: re-projected depths must match exactly.
        Kd = ad.depth_intrinsics((2555.0, 2555.0, 1935.0, 1081.0), 3840, 256)
        depth, conf = np.full((144, 256), 5.0), np.full((144, 256), 2, np.uint8)
        poses = [np.eye(4), np.eye(4)]
        poses[1][0, 3] = 1.0
        pts = ad.backproject(depth, conf >= 2, Kd)
        err = ad.lidar_agreement([pts, pts], poses, [depth, depth], [conf, conf], Kd, 2, 1)
        self.assertGreater(len(err), 1000)
        self.assertLess(err.max(), 1e-9)


if __name__ == "__main__":
    unittest.main()
