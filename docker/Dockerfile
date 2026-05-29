FROM pytorch/pytorch:2.1.2-cuda11.8-cudnn8-devel

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    unzip \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# torchvision matching PyTorch 2.1.2 + CUDA 11.8
RUN pip install --no-cache-dir \
    "torchvision==0.16.2" \
    --index-url https://download.pytorch.org/whl/cu118

# pytorch-scatter for CUDA 11.8
RUN pip install --no-cache-dir \
    torch-scatter \
    -f https://data.pyg.org/whl/torch-2.1.2+cu118.html

# All other dependencies from environment.yml (excluding PyTorch, submodules)
RUN pip install --no-cache-dir \
    "numpy==1.26.4" \
    gdown \
    "plyfile==0.8.1" \
    tqdm \
    PyYAML \
    matplotlib \
    opencv-python-headless \
    einops \
    wandb \
    lpips \
    laspy \
    jaxtyping \
    torchviz \
    open3d \
    "viser==1.0.15" \
    "nerfview==0.0.3"

WORKDIR /workspace/TLC-Calib

# Build context is project root, so path includes docker/
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/bash"]
