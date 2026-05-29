#!/bin/bash
set -e

install_if_missing() {
    local module=$1
    local path=$2
    if ! python -c "import $module" 2>/dev/null; then
        echo "[setup] Installing $path ..."
        pip install --no-cache-dir "$path"
    fi
}

install_if_missing diff_gaussian_rasterization_w_pose submodules/diff-gaussian-rasterization-w-pose
install_if_missing simple_knn                         submodules/simple-knn
install_if_missing diff_gaussian_rasterization        nvs_eval/submodules/diff-gaussian-rasterization

exec "$@"
