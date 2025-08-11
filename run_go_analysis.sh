#!/bin/bash

# 获取环境变量或使用默认值
ORGANISM=${ORGANISM:-"org.Hs.eg.db"}
PVAL_CUTOFF=${PVAL_CUTOFF:-0.05}
QVAL_CUTOFF=${QVAL_CUTOFF:-0.2}
ONTOLOGY=${ONTOLOGY:-"BP"}
PLOT_WIDTH=${PLOT_WIDTH:-10}
PLOT_HEIGHT=${PLOT_HEIGHT:-8}
PLOT_DPI=${PLOT_DPI:-300}

# 创建输出目录
mkdir -p /mnt/out/{tables,plots}

# 检查输入文件
bed_files=(/mnt/in/*.bed)
if [ ${#bed_files[@]} -eq 0 ]; then
  echo "Error: No BED files found in /mnt/in"
  exit 1
fi

# R脚本内容
R_SCRIPT=$(cat <<EOF
library(clusterProfiler)
library(org.Hs.eg.db)
library(ggplot2)
library(ChIPseeker)
library(GenomicRanges)

# 处理每个BED文件
for (bed_file in commandArgs(TRUE)) {
  # 获取基础文件名
  base_name <- tools::file_path_sans_ext(basename(bed_file))
  
  # 读取BED文件
  peaks <- readPeakFile(bed_file)
  
  # 注释peak
  peak_anno <- annotatePeak(peaks, 
                           TxDb=TxDb.Hsapiens.UCSC.hg19.knownGene,
                           annoDb="$ORGANISM")
  
  # 获取基因列表
  gene_list <- unique(peak_anno@anno\$geneId)
  
  # GO富集分析
  ego <- enrichGO(gene          = gene_list,
                  OrgDb         = "$ORGANISM",
                  ont           = "$ONTOLOGY",
                  pAdjustMethod = "BH",
                  pvalueCutoff  = $PVAL_CUTOFF,
                  qvalueCutoff  = $QVAL_CUTOFF,
                  readable      = TRUE)
  
  if (nrow(ego) > 0) {
    # 保存结果表格
    result_file <- paste0("/mnt/out/tables/", base_name, ".go_enrichment.tsv")
    write.table(ego, file=result_file, sep="\t", quote=FALSE, row.names=FALSE)
    
    # 创建并保存图表
    plot_file <- paste0("/mnt/out/plots/", base_name, ".go_enrichment.png")
    
    p1 <- barplot(ego, showCategory=20) + 
          ggtitle(paste("GO Enrichment -", base_name)) +
          theme(text = element_text(size=12))
    
    p2 <- dotplot(ego, showCategory=20) + 
          ggtitle(paste("GO Enrichment -", base_name)) +
          theme(text = element_text(size=12))
    
    ggsave(plot_file, p1, width=$PLOT_WIDTH, height=$PLOT_HEIGHT, dpi=$PLOT_DPI)
    ggsave(sub(".png$","_dotplot.png", plot_file), p2, width=$PLOT_WIDTH, height=$PLOT_HEIGHT, dpi=$PLOT_DPI)
    
    message(paste("Processed", bed_file))
  } else {
    warning(paste("No significant GO terms found for", bed_file))
  }
}
EOF
)

# 处理每个BED文件
for bed_file in "${bed_files[@]}"; do
  echo "Processing $bed_file..."
  Rscript -e "$R_SCRIPT" "$bed_file"
done

echo "GO analysis completed. Results saved to /mnt/out"
