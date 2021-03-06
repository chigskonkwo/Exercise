
rm(list=ls())

library(dplyr)
library(gplots)
library(ggplot2)
library(forcats)
library(tibble)
library(Mfuzz)
library(DESeq2)
library(tidyverse)
library(RColorBrewer)
library(biomaRt)
library(sva)
library(varhandle)
library(clusterProfiler)
library(DOSE)
library(xlsx)
library(openxlsx)
library(AnnotationDbi)
library(org.Rn.eg.db)

dataFolder <- setwd("/Users/Chigoziri/MoTrPAC")
phenotypeDataFile <- "phenotype/merged_dmaqc_data2019-10-15.txt"
heartCountsFile <- "transcriptomics/T58_heart/rna-seq/results/MoTrPAC_rsem_genes_count_heart_v1.txt"
phenotypeData <- read.table(file=phenotypeDataFile, header = TRUE, sep="\t", quote="", comment.char="")
heartCounts <- floor(read.csv(file=heartCountsFile, header = TRUE, row.names = 1, sep="\t", quote="", comment.char=""))

saveFolder <- setwd("/Users/Chigoziri/MoTrPAC/heartCtrl")

phenotypeData[,1] <- as.character(phenotypeData[,1])

animalGroup <- phenotypeData$animal.key.anirandgroup
animalGroupFactor <- fct_infreq(factor(animalGroup))

names(heartCounts) <- substring(names(heartCounts), 2)
sampleIDsHeart <- colnames(heartCounts)
vialIDs <- as.character(phenotypeData$vial_label)

#Stratify data based on condition
heartPhenotypes <- subset(phenotypeData,phenotypeData$vial_label %in% sampleIDsHeart)
ControlIPEPhenotypes <- subset(heartPhenotypes,heartPhenotypes$animal.key.anirandgroup %in% "Control - IPE")
Control7hrPhenotypes <- subset(heartPhenotypes,heartPhenotypes$animal.key.anirandgroup %in% "Control - 7 hr")
ExerciseIPEPhenotypes <- subset(heartPhenotypes,heartPhenotypes$animal.key.anirandgroup %in% "Exercise - IPE")
Exercise0.5hrPhenotypes <- subset(heartPhenotypes,heartPhenotypes$animal.key.anirandgroup %in% "Exercise - 0.5 hr")
Exercise1hrPhenotypes <- subset(heartPhenotypes,heartPhenotypes$animal.key.anirandgroup %in% "Exercise - 1 hr")
Exercise4hrPhenotypes <- subset(heartPhenotypes,heartPhenotypes$animal.key.anirandgroup %in% "Exercise - 4 hr")
Exercise7hrPhenotypes <- subset(heartPhenotypes,heartPhenotypes$animal.key.anirandgroup %in% "Exercise - 7 hr")
Exercise24hrPhenotypes <- subset(heartPhenotypes,heartPhenotypes$animal.key.anirandgroup %in% "Exercise - 24 hr")
Exercise48hrPhenotypes <- subset(heartPhenotypes,heartPhenotypes$animal.key.anirandgroup %in% "Exercise - 48 hr")

heartGroups <- heartPhenotypes$animal.key.anirandgroup
heartGroupsFactor <- fct_infreq(factor(heartGroups))

####Split data into experimental groups based on vial label ID
ControlIPEIDs <- as.character(intersect(colnames(heartCounts), ControlIPEPhenotypes$vial_label))
ControlIPEData <- dplyr::select(heartCounts, ControlIPEIDs)

Control7hrIDs <- as.character(intersect(colnames(heartCounts), Control7hrPhenotypes$vial_label))
Control7hrData <- dplyr::select(heartCounts, Control7hrIDs)

ExerciseIPEIDs <- as.character(intersect(colnames(heartCounts), ExerciseIPEPhenotypes$vial_label))
ExerciseIPEData <- dplyr::select(heartCounts, ExerciseIPEIDs)

Exercise0.5hrIDs <- as.character(intersect(colnames(heartCounts), Exercise0.5hrPhenotypes$vial_label))
Exercise0.5hrData <- dplyr::select(heartCounts, Exercise0.5hrIDs)

Exercise1hrIDs <- as.character(intersect(colnames(heartCounts), Exercise1hrPhenotypes$vial_label))
Exercise1hrData <- dplyr::select(heartCounts, Exercise1hrIDs)

Exercise4hrIDs <- as.character(intersect(colnames(heartCounts), Exercise4hrPhenotypes$vial_label))
Exercise4hrData <- dplyr::select(heartCounts, Exercise4hrIDs)

Exercise7hrIDs <- as.character(intersect(colnames(heartCounts), Exercise7hrPhenotypes$vial_label))
Exercise7hrData <- dplyr::select(heartCounts, Exercise7hrIDs)

Exercise24hrIDs <- as.character(intersect(colnames(heartCounts), Exercise24hrPhenotypes$vial_label))
Exercise24hrData <- dplyr::select(heartCounts, Exercise24hrIDs)

Exercise48hrIDs <- as.character(intersect(colnames(heartCounts), Exercise48hrPhenotypes$vial_label))
Exercise48hrData <- dplyr::select(heartCounts, Exercise48hrIDs)

###################

# Make the gene IDs a column name in order to join columns effectively
ControlIPEData_Join <- rownames_to_column(as.data.frame(ControlIPEData), var = "Gene ID") 
ExerciseIPEData_Join <- rownames_to_column(as.data.frame(ExerciseIPEData), var = "Gene ID")
Exercise0.5hrData_Join <- rownames_to_column(as.data.frame(Exercise0.5hrData), var = "Gene ID")
Exercise1hrData_Join <- rownames_to_column(as.data.frame(Exercise1hrData), var = "Gene ID")
Exercise4hrData_Join <- rownames_to_column(as.data.frame(Exercise4hrData), var = "Gene ID")
Exercise7hrData_Join <- rownames_to_column(as.data.frame(Exercise7hrData), var = "Gene ID")
Exercise24hrData_Join <- rownames_to_column(as.data.frame(Exercise24hrData), var = "Gene ID")
Exercise48hrData_Join <- rownames_to_column(as.data.frame(Exercise48hrData), var = "Gene ID")

#Combine all data for all time points
dataJoin1 <- inner_join(ControlIPEData_Join, ExerciseIPEData_Join)
dataJoin2 <- inner_join(dataJoin1, Exercise0.5hrData_Join)
dataJoin3 <- inner_join(dataJoin2, Exercise1hrData_Join)
dataJoin4 <- inner_join(dataJoin3, Exercise4hrData_Join)
dataJoin5 <- inner_join(dataJoin4, Exercise7hrData_Join)
dataJoin6 <- inner_join(dataJoin5, Exercise24hrData_Join)
dataJoin7 <- inner_join(dataJoin6, Exercise48hrData_Join)
dataAllTimes <- column_to_rownames(dataJoin7, var = "Gene ID") # Remove gene ID column

#######

##Set up count matrix input and coldata parameters
controlIPENames <- sprintf("ControlIPE%s",seq(1:nrow(ControlIPEPhenotypes)))
exerciseIPENames <- sprintf("ExerciseIPE%s",seq(1:nrow(ExerciseIPEPhenotypes)))
exercise0.5hrNames <- sprintf("Exercise0.5hr%s",seq(1:nrow(Exercise0.5hrPhenotypes)))
exercise1hrNames <- sprintf("Exercise1hr%s",seq(1:nrow(Exercise1hrPhenotypes)))
exercise4hrNames <- sprintf("Exercise4hr%s",seq(1:nrow(Exercise4hrPhenotypes)))
exercise7hrNames <- sprintf("Exercise7hr%s",seq(1:nrow(Exercise7hrPhenotypes)))
exercise24hrNames <- sprintf("Exercise24hr%s",seq(1:nrow(Exercise24hrPhenotypes)))
exercise48hrNames <- sprintf("Exercise48hr%s",seq(1:nrow(Exercise48hrPhenotypes)))
samples <- c(controlIPENames,exerciseIPENames,exercise0.5hrNames,exercise1hrNames,
             exercise4hrNames,exercise7hrNames,exercise24hrNames,exercise48hrNames)
sampleIDs <- colnames(dataAllTimes)
Condition <- c(rep("Control_IPE",nrow(ControlIPEPhenotypes)),rep("Exercise_IPE",nrow(ExerciseIPEPhenotypes)),
               rep("Exercise0.5hr",nrow(Exercise0.5hrPhenotypes)),rep("Exercise01hr",nrow(Exercise1hrPhenotypes)),
               rep("Exercise04hr",nrow(Exercise4hrPhenotypes)),rep("Exercise07hr",nrow(Exercise7hrPhenotypes)),
               rep("Exercise24hr",nrow(Exercise24hrPhenotypes)),rep("Exercise48hr",nrow(Exercise48hrPhenotypes)))

Time <- c(rep("IPE",nrow(ControlIPEPhenotypes)),rep("IPE",nrow(ExerciseIPEPhenotypes)),rep("0.5hr",nrow(Exercise0.5hrPhenotypes)),
          rep("1hr",nrow(Exercise1hrPhenotypes)),rep("4hr",nrow(Exercise4hrPhenotypes)),
          rep("7hr",nrow(Exercise7hrPhenotypes)),rep("24hr",nrow(Exercise24hrPhenotypes)),
          rep("48hr",nrow(Exercise48hrPhenotypes)))

coldata <- data.frame(samples,sampleIDs,Condition,Time)
rownames(coldata) <- sampleIDs

#Perform differential expression analysis
dds <- DESeqDataSetFromMatrix(countData = dataAllTimes,
                              colData = coldata,
                              design = ~Condition)

keep <- rowSums(counts(dds)) >= 10
dds <- dds[keep,]

factorMat <- c("Control_IPE","Exercise_IPE","Exercise0.5hr","Exercise01hr","Exercise04hr","Exercise07hr","Exercise24hr","Exercise48hr")
dds$Condition <- factor(dds$Condition, levels=factorMat)

#Perform LRT
dds_LRT <- DESeq(dds, test="LRT", reduced = ~1) #Perform LRT to compare all levels at once, as opposed to pairwise comparisons
res_LRT <- results(dds_LRT) #Alpha by default is set to 0.1

#Convert Ensembl IDs to gene symbols and Entrez IDs
res_LRT$symbol = mapIds(org.Rn.eg.db,
                        keys=row.names(res_LRT), 
                        column="SYMBOL",
                        keytype="ENSEMBL",
                        multiVals="first")
res_LRT$ENTREZ = mapIds(org.Rn.eg.db,
                        keys=row.names(res_LRT), 
                        column="ENTREZID",
                        keytype="ENSEMBL",
                        multiVals="first")

#Apply variance stabilizing transformation
rld<- vst(dds, blind= FALSE)
rld_mat <- assay(rld)

save(res_LRT, rld, rld_mat, coldata, file = "heart_LRTData.RData")

####Perform Mfuzz Analysis####

#Identify significant genes which meet cutoff
padj.cutoff <- 0.05

sig_res_LRT <- res_LRT %>%
  data.frame() %>%
  rownames_to_column(var="gene") %>% 
  as_tibble() %>% 
  filter(padj < padj.cutoff)

# Get sig gene lists
sigLRT_genes <- sig_res_LRT %>% 
  pull(gene)

# Subset results for faster cluster finding
clustering_sig_genes <- sig_res_LRT %>%
  arrange(padj) %>%
  head(n=1000)


# Obtain rlog values for those significant genes
cluster_rld <- rld_mat[clustering_sig_genes$gene, ]

#Z-score scale transformation
rld_scale <- scale(t(cluster_rld))
rld_scale <- t(rld_scale)

controlIPEVals <- rld_scale[,coldata$sampleIDs[coldata$Condition=="Control_IPE"]] 
controlIPEMeans <- data.frame(rowMeans(controlIPEVals))
colnames(controlIPEMeans) <- "Control_IPE"
controlIPEJoin <- rownames_to_column(controlIPEMeans, var="geneNames")

exerciseIPEVals <- rld_scale[,coldata$sampleIDs[coldata$Condition=="Exercise_IPE"]] 
exerciseIPEMeans <- data.frame(rowMeans(exerciseIPEVals))
colnames(exerciseIPEMeans) <- "Exercise_IPE"
exerciseIPEJoin <- rownames_to_column(exerciseIPEMeans, var="geneNames")

exercise0.5hrVals <- rld_scale[,coldata$sampleIDs[coldata$Condition=="Exercise0.5hr"]] 
exercise0.5hrMeans <- data.frame(rowMeans(exercise0.5hrVals))
colnames(exercise0.5hrMeans) <- "Exercise0.5hr"
exercise0.5hrJoin <- rownames_to_column(exercise0.5hrMeans, var="geneNames")

exercise1hrVals <- rld_scale[,coldata$sampleIDs[coldata$Condition=="Exercise01hr"]] 
exercise1hrMeans <- data.frame(rowMeans(exercise1hrVals))
colnames(exercise1hrMeans) <- "Exercise1hr"
exercise1hrJoin <- rownames_to_column(exercise1hrMeans, var="geneNames")

exercise4hrVals <- rld_scale[,coldata$sampleIDs[coldata$Condition=="Exercise04hr"]] 
exercise4hrMeans <- data.frame(rowMeans(exercise4hrVals))
colnames(exercise4hrMeans) <- "Exercise4hr"
exercise4hrJoin <- rownames_to_column(exercise4hrMeans, var="geneNames")

exercise7hrVals <- rld_scale[,coldata$sampleIDs[coldata$Condition=="Exercise07hr"]] 
exercise7hrMeans <- data.frame(rowMeans(exercise7hrVals))
colnames(exercise7hrMeans) <- "Exercise7hr"
exercise7hrJoin <- rownames_to_column(exercise7hrMeans, var="geneNames")

exercise24hrVals <- rld_scale[,coldata$sampleIDs[coldata$Condition=="Exercise24hr"]] 
exercise24hrMeans <- data.frame(rowMeans(exercise24hrVals))
colnames(exercise24hrMeans) <- "Exercise24hr"
exercise24hrJoin <- rownames_to_column(exercise24hrMeans, var="geneNames")

exercise48hrVals <- rld_scale[,coldata$sampleIDs[coldata$Condition=="Exercise48hr"]] 
exercise48hrMeans <- data.frame(rowMeans(exercise48hrVals))
colnames(exercise48hrMeans) <- "Exercise48hr"
exercise48hrJoin <- rownames_to_column(exercise48hrMeans, var="geneNames")

dataJoin1 <- inner_join(controlIPEJoin, exerciseIPEJoin)
dataJoin2 <- inner_join(dataJoin1, exercise0.5hrJoin)
dataJoin3 <- inner_join(dataJoin2, exercise1hrJoin)
dataJoin4 <- inner_join(dataJoin3, exercise4hrJoin)
dataJoin5 <- inner_join(dataJoin4, exercise7hrJoin)
dataJoin6 <- inner_join(dataJoin5, exercise24hrJoin)
dataJoin7 <- inner_join(dataJoin6, exercise48hrJoin)
dataAllTimes <- column_to_rownames(dataJoin7, var = "geneNames") # Remove gene ID column
dataAllTimesMat <- as.matrix(dataAllTimes)  

heart_eset <- ExpressionSet(assayData = dataAllTimesMat)
mest <- mestimate(heart_eset)

#Run Mfuzz algorithm
dataFuzz <- mfuzz(heart_eset,8,mest)

#Genes within the core of the cluster, with a membership score greater than 0.4
dataFuzz_acore <- acore(heart_eset,dataFuzz,min.acore=0.4) 

#save(dataFuzz, dataFuzz_acore, file="heart_dataFuzz.RData")

#Determine the number and percentage of genes in each cluster
numGenes <- vector(mode = "list", length = length(dataFuzz_acore))
percentGenes <- vector(mode = "list", length = length(dataFuzz_acore))

for (i in 1:length(dataFuzz_acore)) {
  numGenes[[i]] <- nrow(dataFuzz_acore[[i]])
}

totalGeneNum <- sum(unlist(numGenes))
for (i in 1:length(dataFuzz_acore)) {
  percentGenes[[i]] <- round(100*(numGenes[[i]]/totalGeneNum), digits=1)
}

graphLabels <- paste("n = ",numGenes," (",percentGenes,"%)",sep="")
#write.csv(graphLabels,file="heart_MfuzzGraphLabels.csv")

#Plot clusters generated from Mfuzz
mfuzz.plot2(heart_eset,dataFuzz,mfrow=c(4,4),min.mem=0.4,time.labels=c("Ctrl","0","0.5","1","4","7","24","48"),
            xlab="Time Post-Exercise (hr)",cex.lab=1.5,cex.axis=1.5) +
  annotate("text", x=1, y=1, label= )
quartz.save(file="heartMfuzzClusters_1000_c8_min.men0.4_clusterNum_t.tiff",type="tiff",width=18, height=15, dpi=300)
dev.off()

#load("heart_dataFuzz.RData")

#Order genes based on their cluster
orderedClusters <- as.data.frame(dataFuzz$cluster[order(dataFuzz$cluster)])
colnames(orderedClusters) <- "Cluster"

dataFuzz$symbol = mapIds(org.Rn.eg.db,
                         keys=names(dataFuzz$cluster), 
                         column="SYMBOL",
                         keytype="ENSEMBL",
                         multiVals="first")
dataFuzz$ENTREZ = mapIds(org.Rn.eg.db,
                         keys=names(dataFuzz$cluster), 
                         column="ENTREZID",
                         keytype="ENSEMBL",
                         multiVals="first")

#Map ENTREZ and symbol for only genes in acore
dataFuzz_acoreList <- vector(mode = "list", length = length(dataFuzz_acore))
for (i in 1:length(dataFuzz_acore)) {
  dataFuzz_acoreList[[i]]$symbol = mapIds(org.Rn.eg.db,
                                          keys=dataFuzz_acore[[i]]$NAME, 
                                          column="SYMBOL",
                                          keytype="ENSEMBL",
                                          multiVals="first")
  dataFuzz_acoreList[[i]]$ENTREZ = mapIds(org.Rn.eg.db,
                                          keys=dataFuzz_acore[[i]]$NAME, 
                                          column="ENTREZID",
                                          keytype="ENSEMBL",
                                          multiVals="first")
}

orderedClusters$symbol <- dataFuzz$symbol[order(dataFuzz$cluster)]
orderedClusters$ENTREZ <- dataFuzz$ENTREZ[order(dataFuzz$cluster)]
orderedClusters <- rownames_to_column(orderedClusters, var="EnsemblID")

##Generate data for dot plots, and save xlsx files for genes in clusters, as well as enrichKEGG files for each cluster
names(dataFuzz_acoreList) <- paste("Cluster", seq(1:length(dataFuzz_acoreList)), sep="")
sheetTitles <- names(dataFuzz_acoreList)

ekeggClusterList <- list()
ekeggDotPlotData <- data.frame(Description=as.character(),
                               GeneRatio=as.numeric(),padj=as.numeric(),cluster=as.character())
ekeggClusterGeneList <- vector(mode = "list", length = length(dataFuzz_acoreList))
names(ekeggClusterGeneList) <- names(dataFuzz_acoreList)

if (file.exists("heartMfuzzClusters_c10_1000.xlsx")==FALSE) {
  geneClustersWB <- createWorkbook()
  
  for (i in 1:length(dataFuzz_acoreList)) {
    # Add some sheets to the workbook
    addWorksheet(geneClustersWB, sheetTitles[i])
    # Write the data to the sheets
    writeData(geneClustersWB, sheet = sheetTitles[i], x = dataFuzz_acoreList[[i]])
  }
  
  saveWorkbook(geneClustersWB, "heartMfuzzClusters_c10_1000.xlsx")
  
  ekeggClustersWB <- createWorkbook()
  ekeggEnrichedPathwaysWB <- createWorkbook()
  addWorksheet(ekeggEnrichedPathwaysWB, "Group Pathways")
  
  for (i in 1:length(dataFuzz_acoreList)) {
    
    gene <- dataFuzz_acoreList[[i]]$ENTREZ #Input only genes which fell into a particular cluster for that enrichment
    ekegg <- enrichKEGG(gene         = gene,
                        organism     = 'rno',
                        pvalueCutoff = 0.05)
    
    ##Use ekegg to convert ENTREZIDs to GeneIDs, save ekegg in xlsx file; 
    ##filter out numbers with no cluster, clusters  with no  enrichment
    if (is.null(ekegg)==FALSE) {
      if (nrow(ekegg)!=0) {
        ekeggMat <- as.data.frame(ekegg)
        ekeggGeneID <- ekeggMat$geneID
        ekeggSplit <- strsplit(ekeggGeneID, "/")
        
        ekeggSymbolList <- vector(mode = "list", length = length(ekeggSplit))
        
        for (j in 1:length(ekeggSplit)) {
          name <- paste("Cluster", as.character(i), sep="")
          ekeggClusterList[[name]] <- ekegg
          
          ekeggUnlist <- unlist(ekeggSplit[[j]])
          ekeggSymbol = mapIds(org.Rn.eg.db,
                               keys=ekeggUnlist, 
                               column="SYMBOL",
                               keytype="ENTREZID",
                               multiVals="first")
          
          ekeggSymbolList[[j]] <- ekeggSymbol
          geneUnlisted <- unlist(ekeggSymbol)
          ekeggMat$GeneSymbol[j] <- paste(geneUnlisted, collapse = "/")
          ekeggMat$KEGGDescription[j] <- paste(ekeggMat$ID[j], ekeggMat$Description[j])
          
          ekeggClusterGeneList[[i]] <- c(as.character(ekeggClusterGeneList[[i]]),ekeggMat$Description[j])
          ekeggClusterGeneList[[i]] <- c(as.character(ekeggClusterGeneList[[i]]),ekeggSymbol)
        }
        
        ekeggGeneSymbol <- ekeggMat$GeneSymbol
        
        # Add some sheets to the workbook
        addWorksheet(ekeggClustersWB, sheetTitles[i])
        # Write the data to the sheets
        writeData(ekeggClustersWB, sheet = sheetTitles[i], x = ekeggMat)
        writeData(ekeggEnrichedPathwaysWB, sheet="Cluster Pathways", ekeggClusterGeneList[[i]], colNames = F,rowNames = T,startRow = 2,startCol = i)
        
        ####
        nCluster <- as.data.frame(rep(paste("Cluster", as.character(i), sep=""),nrow(ekegg)))
        data <- data.frame(ekegg$Description,ekegg$GeneRatio,ekegg$p.adjust,nCluster)
        
        ekeggDotPlotData <- rbind(ekeggDotPlotData,data)
      }
    }
  }
  saveWorkbook(ekeggClustersWB, "heartMfuzzClusters_c10_1000_enrichKEGG_0.05_FINAL.xlsx")
  saveWorkbook(ekeggEnrichedPathwaysWB,"heartMfuzzClusters_enrichedPathways.xlsx")
}

names(ekeggDotPlotData) <- c("Description","GeneRatio","padj","Cluster")

#Specify levels to have clusters in order on dot plot
ekeggDotPlotData$Cluster <- factor(ekeggDotPlotData$Cluster,levels=c("Cluster 1","Cluster 2","Cluster 3","Cluster 4","Cluster 5","Cluster 6","Cluster 7","Cluster 8","Cluster 9","Cluster 10"))
#Convert GeneRatio from fraction character to decimal
ekeggDotPlotData$GeneRatio <- sapply(ekeggDotPlotData$GeneRatio, function(x) eval(parse(text=x)))

#Save dot plot as .tiff
tiff("heartMfuzzClusters_c8_1000_DotPlot_0.05.tiff", units="in", width=12, height=10, res=300)

heartDotPlot <- ggplot(ekeggDotPlotData, aes(x= Cluster, y=reorder(Description, dplyr::desc(Description)), size=GeneRatio, color=padj, group=Cluster)) + geom_point(alpha = 0.8) + 
  theme_bw(base_size = 14) + ylab("Description")
heartDotPlot = heartDotPlot+scale_color_gradient(low = "red2",  high = "mediumblue", space = "Lab", limit = c(0.00000000001,0.05))
heartDotPlot+scale_size(range = c(2, 8))

dev.off()

