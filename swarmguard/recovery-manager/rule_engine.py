#!/usr/bin/env python3
"""Rule Engine - Evaluates threshold rules"""

import logging

logger = logging.getLogger(__name__)


class RuleEngine:
    def __init__(self, config):
        self.config = config
        self.scenario1_config = config.get('scenarios.scenario1_migration', {})
        self.scenario2_config = config.get('scenarios.scenario2_scaling', {})
        logger.info("Rule engine initialized")

    def evaluate_scenario1(self, metrics: dict) -> bool:
        if not self.scenario1_config.get('enabled', True):
            return False
        cpu = metrics.get('cpu_percent', 0)
        mem = metrics.get('memory_percent', 0)
        net = metrics.get('network_percent', 0)
        return ((cpu > self.scenario1_config.get('cpu_threshold', 75) or
                mem > self.scenario1_config.get('memory_threshold', 80)) and
                net < self.scenario1_config.get('network_threshold_max', 35))

    def evaluate_scenario2(self, metrics: dict) -> bool:
        if not self.scenario2_config.get('enabled', True):
            return False
        cpu = metrics.get('cpu_percent', 0)
        mem = metrics.get('memory_percent', 0)
        net = metrics.get('network_percent', 0)
        return ((cpu > self.scenario2_config.get('cpu_threshold', 75) or
                mem > self.scenario2_config.get('memory_threshold', 80)) and
                net > self.scenario2_config.get('network_threshold_min', 65))
