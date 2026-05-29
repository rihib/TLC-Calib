# TLC-Calib Docker セットアップ

## 必要なもの

- Docker Engine
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)

## ファイル構成

```
docker/
├── Dockerfile          # ベースイメージ + Python 依存パッケージ
├── docker-compose.yml  # ボリュームマウント + GPU 設定
├── entrypoint.sh       # 初回起動時に CUDA 拡張をビルド
└── README.md
```

## クイックスタート

すべてのコマンドは**プロジェクトルート**（`TLC-Calib/`）で実行する。

### 1. イメージをビルドする

```bash
docker compose -f docker/docker-compose.yml build
```

### 2. コンテナを起動してシェルに入る

```bash
docker compose -f docker/docker-compose.yml run --rm tlc-calib
```

初回起動時は `entrypoint.sh` が以下の CUDA 拡張を自動でビルドする（数分かかる）：

- `submodules/diff-gaussian-rasterization-w-pose`
- `submodules/simple-knn`
- `nvs_eval/submodules/diff-gaussian-rasterization`

2回目以降はビルド済みかどうかを確認してスキップする。

### 3. データセットをダウンロードする（コンテナ内で実行）

```bash
gdown --folder https://drive.google.com/drive/folders/1P9EcXuyUL9NZpgj-IU44-UfJUDiEZ7zg -O data/TLC-Calib
```

ダウンロード後、アーカイブを展開する：

```bash
cd data/TLC-Calib
find . -name "*.zip" -execdir unzip -n "{}" \;
cd /workspace/TLC-Calib
```

`data/` はマウント配下にあるため、コンテナを終了・削除してもデータは残る。一度だけ実行すればよい。

### 4. 学習を実行する（コンテナ内で実行）

```bash
python train.py -s data/TLC-Calib/KITTI-360/large_rotation \
  -m outputs/kitti-360/large_rotation/eval \
  --eval --from_lidar --use_rig --opt_pose --pose_scheduler --adaptive_voxel \
  --dataset kitti-360
```

## 補足

- プロジェクトルートはコンテナ内の `/workspace/TLC-Calib` にマウントされるため、ファイルの変更はホストとコンテナで即座に共有される。
- `data/` や `outputs/` もマウント配下にあるため、コンテナを終了・削除しても学習結果は残る。
- コンテナを削除して再作成した場合、次回起動時に CUDA 拡張が再ビルドされる。

## 学習結果の確認

### 学習完了時の出力例

```
Training progress: 100%|████████| 30000/30000 [14:12<00:00, 35.20it/s, Loss=0.0808, are=0.1079, ate=0.1073, N=369820]

[ITER 30000] Evaluating test: Photo 0.040505 PSNR 22.459946, Rot_Err: 0.107243[deg], Trans_Err: 0.107389[m]
[CAM 0] Evaluating test: Rot_Err: 0.104038[deg], Trans_Err: 0.107865[m]
[CAM 1] Evaluating test: Rot_Err: 0.072395[deg], Trans_Err: 0.112141[m]
[CAM 2] Evaluating test: Rot_Err: 0.159047[deg], Trans_Err: 0.094303[m]
[CAM 3] Evaluating test: Rot_Err: 0.093491[deg], Trans_Err: 0.115246[m]

[ INFO ] Training complete 0:14:12
```

### 主要指標の見方

| 指標 | 意味 |
|---|---|
| `Rot_Err [deg]` | 回転キャリブレーション誤差（小さいほど良い） |
| `Trans_Err [m]` | 並進キャリブレーション誤差（小さいほど良い） |
| `PSNR [dB]` | 画像再構成品質（大きいほど良い） |
| `Loss` | 学習損失 |

### 出力ファイル

学習結果は `-m` で指定した出力ディレクトリ（例: `outputs/kitti-360/large_rotation/eval/`）に保存される。マウント経由でホスト上にも即座に反映される。

```
eval/
├── config.yml                        # 学習設定の記録
├── train_info.json                   # 学習時間・メモリ統計
├── outputs.log                       # ログ全文
└── point_cloud/
    └── iteration_30000/              # 最適化済みガウシアン表現・キャリブレーション結果
```

### 詳細評価（任意）

```bash
# キャリブレーション精度の詳細 → rig_results.json が生成される
python metrics_pose.py -m outputs/kitti-360/large_rotation/eval

# NVS 品質の詳細 → nvs_results.json が生成される
python metrics_nvs.py -m outputs/kitti-360/large_rotation/eval
```

## ベースイメージの選定理由

ベースイメージには `pytorch/pytorch:2.1.2-cuda11.8-cudnn8-devel` を採用した。

### NVIDIA NGC イメージ（`nvcr.io/nvidia/pytorch`）を使わない理由

NGC イメージは NVIDIA が最適化した公式コンテナだが、このプロジェクトには適合しない。

理由はリリースのタイミングにある。NGC イメージは 2023 年初頭に CUDA 12.x へ移行しており、PyTorch 2.1.x が登場した 2023 年 10 月以降のイメージはすべて CUDA 12.x を搭載している。一方、CUDA 11.8 を搭載した NGC イメージ（`22.12-py3` 等）には PyTorch 1.x しか含まれていない。**PyTorch 2.1.x と CUDA 11.8 を同時に満たす NGC イメージは存在しない。**

[Framework Containers Support Matrix](https://docs.nvidia.com/deeplearning/frameworks/support-matrix/index.html#framework-matrix-2022) を参照すると、CUDA 11.8 を使用するには 22.xx の NGC イメージを選ぶ必要があるが、これらはすべて PyTorch 1.1x を使用しているので、要件を満たさないことがわかる。

加えて、NGC の PyTorch は `2.1.0a0+32f93b1` のような開発版ビルドであり、`environment.yml` が要求する安定版 `2.1.2` とは異なる。

### `pytorch/pytorch:2.1.2-cuda11.8-cudnn8-devel` を選んだ理由

| 要件 | このイメージ |
|---|---|
| PyTorch 2.1.2（安定版） | 完全一致 |
| CUDA 11.8 | 完全一致 |
| nvcc（CUDA コンパイラ） | `devel` タグに含まれる |

`devel` タグが必須なのは、`submodules/` 以下の CUDA 拡張（`.cu` ファイル）をコンテナ内でコンパイルするために nvcc が必要なためである。`runtime` タグには nvcc が含まれないためビルドに失敗する。
