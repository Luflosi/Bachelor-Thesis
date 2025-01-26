# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{
  cacheID = 0;
  platform = "VM";
  test_duration_s = 60;
  ip_payload_size = 1400;
  encapsulation = "none";
  delay_time_ms = 200;
  delay_jitter_ms = 100;
  delay_distribution = "normal";
  loss_per_mille = 5;
  loss_correlation = "0%";
  duplicate_per_mille = 2;
  duplicate_correlation = "0%";
  reorder_per_mille = 1;
}
