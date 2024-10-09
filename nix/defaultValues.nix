# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{
  test_duration_s = 60;
  delay_time_ms = 200;
  delay_jitter_ms = 100;
  delay_distribution = "normal";
  loss_per_mille = 5;
  loss_correlation = "25%";
  duplicate_per_mille = 2;
  duplicate_correlation = "0%";
  reorder_per_mille = 1;
}
