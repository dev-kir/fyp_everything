#!/bin/bash
# Section 0: Environment Information
# Run from: fyp-report/03-chapter4-evidence/scripts/

set -e

# Create output directory
mkdir -p ../raw_outputs

echo "Collecting environment information..."

# Docker version
ssh master "docker version" > ../raw_outputs/00_docker_version.txt

# Swarm info
ssh master "docker info | grep -A 20 'Swarm:'" > ../raw_outputs/00_swarm_info.txt

# Cluster nodes
ssh master "docker node ls" > ../raw_outputs/00_cluster_nodes.txt

# Networks
ssh master "docker network ls" > ../raw_outputs/00_networks.txt

# Git branch and commit
git branch --show-current > ../raw_outputs/00_git_branch.txt
git log -1 --oneline > ../raw_outputs/00_git_commit.txt

echo "Environment info collected in ../raw_outputs/"
ls -lh ../raw_outputs/00_*
