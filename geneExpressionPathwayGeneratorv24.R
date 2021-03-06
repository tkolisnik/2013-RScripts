## geneExpressionPathwayGeneratorv24.R

# Created by Tyler Kolisnik and Mark Bieda.
# January 22, 2015.

# This program was created to help Dr. Robert Newton at the University of Calgary analyze Gene Expression Microarray Data from Affymetrix platforms by producing visualizations of the up and downregulated genes within biological pathways. 

## Directions: 
# 1. Install pathview and gage packages from bioconductor if not installed already. 
# 2. Ensure your input file is in the correct format, as specified by the Important Information and the Sample below.
# 3. Create an output directory folder. 
# 4. Adjust input parameters in the parameter block. 
# 5. Run the Program.

## Important Information:
# This program takes a tab-separated text file as input, with two columns, the first row is a header labeled EntrezID /t FoldChange and the subsequent rows being the numerical Entrez Ids \t numerical log2 FoldChange values.
# Output is two lists (One for upregulated pathways, One for downregulated pathways, as well as a folder of image files, KeggNative and Graphviz (when available) Visualizations are included.

## Sample input file, note that the separation is actually by tab:
#EntrezID  FoldChange
#2289 13.4086
#7704	12.753
#2289	12.4731
#2289	11.1761
#116154	8.37652
#116154	7.91311

## Output information:
# In the outputDirectory two text files and one folder will be outputted. 
# The text files are lists of up regulated and down regulated pathways, showing Pathway Code, Pathway Name, p Values, and	q values for each. 
# The folder (as named by the pathwayDirectoryName parameter) will contain the images of the outputted pathways. 
# This includes for each pathway: a blank .png file illustrating the pathway, a .png file colored by fold change (red for increased levels, green for decreased levels, as shown by legend on graph), and a .xml file showing a .xml representation of the KEGG pathway maps (can be used with Cytoscape and KGML reader).
# For some pathways a colored by fold change .pdf file (generated by graphviz) will also be generated. This shows an alternative depiction of the pathway, and comes with a legend on the second page. 

########################### Begin Parameter Block ###########################
inputFile <- ("/home/tylerk/newtonWork/newtonInput/biopsy_array_data_entrezratio.csv") # String showing absolute path of a text file with entrezIDs and log2 Fold Change values, see Important Information (above) for more details. No trailing /. 
outputDirectory <- ("/home/tylerk/newtonWork/newtonOutput") # String showing the absolute path files will be outputted to, with no trailing /. THIS FOLDER MUST EXIST BEFORE RUNNING PROGRAM. 
runName <- "Ratiov25" # String depicting a common run name that will be appended to the names of all output files. 
pValueCutoff <- 0.2 # Numeric The pValue threshold for the Fold Change. 
KEGGspeciesCode <- "hsa" # String Kegg species code, default = "hsa" (human), more available on bioconductor website. 
pathwayDirectoryName <- "pathway_imagesRatio3" # String depicting the name of the folder within the output directory that will be created to contain the pathway images. 
isLog2 <- FALSE # Boolean that describes the log2 state of data at input. Set to FALSE if input data is not in log2, set to TRUE if it is in log2. 
########################### End Parameter Block ###########################

# Load Dependencies.
library(pathview)
library(gage) 

setwd(outputDirectory)
pathwayDirectory <- paste(outputDirectory, pathwayDirectoryName, sep="/")

# Reads in the file.
geneInfo <- unique(read.delim(inputFile, header=TRUE, sep="\t"))

if (isLog2 == FALSE){
  geneInfo$FoldChange <- log2(geneInfo$FoldChange) # Convert the data to log2. 
}

geneInfo <- geneInfo
geneList <- unique(geneInfo$EntrezID)
geneList <- geneList[!is.na(geneList)]
geneListChar <- as.character(geneList)

# Removes blank spaces, ---, entrez ids with /// in them. This program cannot handle these. 
goodGeneListRows <- !grepl("[^0-9]+", geneListChar) & grepl("[0-9]+",geneListChar)
geneListAdj <- geneListChar[goodGeneListRows]
dataMatrix <- matrix(nrow=length(geneListAdj), ncol=1) 
rownames(dataMatrix) <- geneListAdj
colnames(dataMatrix) <- "FoldChange"

# For each unique Entrez ID, finds the highest fold change associated with that gene.
for (i in 1:length(geneListAdj)) {
  gene <- as.character(geneListAdj[i])
  maxFoldChange <- max(geneInfo$FoldChange[which(geneInfo$EntrezID == gene)])
  dataMatrix[gene,] <- maxFoldChange
}

data(kegg.gs) # Load in the KEGG pathway data.
gageOutput <- gage(dataMatrix, gsets = kegg.gs, ref=NULL, samp=NULL)

# Calculate pathways that were Up-Regulated.
pathwayData <- gageOutput$greater[,c("p.val", "q.val")]
pathCode <- substr(rownames(pathwayData), 1, 8)
pathName <- substr(rownames(pathwayData), 9, length(rownames(pathwayData)))
pathwayData <- cbind(pathCode, pathName ,pathwayData)
colnames(pathwayData) <- c("Pathway Code", "Pathway Name", "p Values", "q value")

# Output a text file of upregulated pathways and meaningful data.
write.table(pathwayData, paste(runName, "upregulated_pathway_list.txt", sep="_"), sep="\t", row.names=FALSE, quote = FALSE)

# Calculate pathways that were Down-Regulated.
pathwayDataDownRegulated <- gageOutput$less[,c("p.val", "q.val")] 
pathCodeDown <- substr(rownames(pathwayDataDownRegulated), 1, 8)
pathNameDown <- substr(rownames(pathwayDataDownRegulated), 9, length(rownames(pathwayDataDownRegulated)))
pathwayDataDown <- cbind(pathCodeDown, pathNameDown, pathwayDataDownRegulated)
colnames(pathwayDataDown) <- c("Pathway Code", "Pathway Name", "p Values", "q value")

# Output a text file of downregulated pathways and meaningful data.
write.table(pathwayDataDown, paste(runName, "downregulated_pathway_list.txt", sep="_"), sep="\t", row.names=FALSE, quote = FALSE)

# Create a folder within the outputDirectory where all of the generated pathway image files will go. Note: Using standard parameters, it is likely several hundred image files will be generated.
system(paste("mkdir ", pathwayDirectory, sep = ""))
setwd(pathwayDirectory)


## Use pathview to create output images.
runPathview <- function(pid, upordown){
  # Output Kegg Native Graphs (.png files, works for all Pathways).
  pathview(gene.data=dataMatrix, pathway.id=pid, kegg.native=T, species=KEGGspeciesCode, plot.col.key = TRUE, same.layer=F, split.group=T, out.suffix=paste(runName, "KEGGnative_",upordown,sep=""))
  # Output Graphviz Graphs (.pdf files, doesn't work for all Pathways).
  pathview(gene.data=dataMatrix, pathway.id=pid, kegg.native=F, species=KEGGspeciesCode, plot.col.key = TRUE, same.layer=F, split.group=T, out.suffix=paste(runName, "graphviz_",upordown,sep=""))
}

# Select Up Regulated Pathways to be printed based on p value (p.val).
selUp <- gageOutput$greater[,"p.val"] < pValueCutoff & !is.na(gageOutput$greater[,"p.val"])
pathIdsUp <- substr(rownames(gageOutput$greater)[selUp], 1, 8)

# Print Selected Up Regulated Pathways.
# Try Catch allows for error handling if a Graphviz visualization does not exist for the pathway ID entered.
pathListUp <- sapply(pathIdsUp, function(pid) tryCatch(runPathview(pid, "upRegulated"), error=function(e) print("This pathway not found")))

# Select Down Regulated Pathways to be printed based on p value (p.val).
selDown <- gageOutput$less[,"p.val"] < pValueCutoff & !is.na(gageOutput$less[,"p.val"])
pathIdsDown <- substr(rownames(gageOutput$less)[selDown], 1, 8)

# Print Selected Down Regulated Pathways .
# Try Catch allows for error handling if a Graphviz visualization does not exist for the pathway ID entered.
pathListDown <- sapply(pathIdsDown, function(pid) tryCatch(runPathview(pid,"downRegulated"), error=function(e) print("This pathway not found")))