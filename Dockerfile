# 使用官方R镜像（基于Debian）
FROM r-base:4.3.2

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8

# 安装系统依赖（包含Python3和pip）
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    bedtools \
    python3 \
    python3-pip \
    python3-venv \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

# 创建Python虚拟环境
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# 安装R包
RUN R -e "install.packages(c('BiocManager', 'ggplot2'), repos='https://cloud.r-project.org')" && \
    R -e "BiocManager::install(c('clusterProfiler', 'org.Hs.eg.db', 'ChIPseeker', 'GenomicRanges'))"

# 在虚拟环境中安装Python包
RUN /opt/venv/bin/pip install --no-cache-dir --upgrade pip && \
    /opt/venv/bin/pip install --no-cache-dir pandas matplotlib

# 创建工作目录
RUN mkdir -p /mnt/{in,out/{tables,plots}}

# 复制入口脚本
COPY run_go_analysis.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/run_go_analysis.sh

# 设置默认环境变量
ENV ORGANISM="org.Hs.eg.db" \
    PVAL_CUTOFF=0.05 \
    QVAL_CUTOFF=0.2 \
    ONTOLOGY="BP" \
    PLOT_WIDTH=10 \
    PLOT_HEIGHT=8 \
    PLOT_DPI=300

ENTRYPOINT ["/usr/local/bin/run_go_analysis.sh"]
