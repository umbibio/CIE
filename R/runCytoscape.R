#' Create Graphs of significant interactions
#'
#' @description Creates graphs of protein-gene interactions based on enrichment analyses
#' by this pipeline
#'
#' @usage createCytoGraph(enrichment, ents, rels, DEGs, p.thresh=0.05,
#'                        fc.thresh = log(1.5), numProt=5, ids=NA,
#'                        numTargets=10)
#' @param enrichment The enrichment tables from the analysis pipeline.  Can be a list
#' of lists (multiple methods and conditions) or a list (multiple conditions, one
#' method), or a single data frame
#'
#' @param ents The ents table used in the enrichment, must be a single data frame
#'
#' @param rels The rels table used in the enrichment, must be a single data frame
#'
#' @param DGEs The differentially expressed gene tables, can be a single data frame
#' or list of data frames matching that which the pipeline was run on.
#'
#' @param p.thresh The p value threshold used in determining the significant
#' differentailly expressed genes for enrichment analysis
#'
#' @param fc.thresh The fold count threshold used in determining the significant
#' differentially expressed genes for enrichment analysis
#'
#' @param numProt The number of protiens, ranked by p.value from enrichment, to include
#' 
#' @param ids Row indices of the regulators you wish to be included in the plot
#'
#' @param numTargets The number of targets of each top regulator to show.  Please note that the
#' number of targets plotted may be smaller than you expect, due to overlap.
#' 
#' @return Opens a browser window with the graph, green = proteins, purple = mRNA
#'
#' @export
#'
#' @examples
#'
#' ChIP1ap <- filterChIPAtlas(1, NA, "auto", NA, "prostate", NA, NA, FALSE)
#' files <- list.files("./", ".txt")
#' degs <- lapply(files, function(x) {
#'    read.table(x, header=T, sep="\t") } )
#' names(degs) <- files
#' methods <- c("Ternary", "Quaternary", "Enrichment", "Fisher")
#' enrichment <- runInferenceModels(NULL, NULL, DEGs=degs,
#'                                 method = methods,
#'                                 ents=ChIP1ap$filteredChIP.ents,
#'                                 rels=ChIP1ap$filteredChIP.rels,
#'                                 useFile=F, useMart=TRUE, useBHLH=TRUE,
#'                                 martFN="../CIE/data/mart_human_TFs.csv",
#'                                 BHLHFN="../CIE/data/BHLH_TFs.txt")
#' createCytoGraph(enrichment, ChIP1ap$filteredChIP.ents,
#'                 ChIP1ap$filteredChIP.rels, degs)

createCytoGraph <- function(enrichment, ents, rels, DGEs, p.thresh=0.05,
                            fc.thresh = log(1.5), numProt=5, ids=NA, numTargets=10) {
    print("Starting Graph Generation")
    if(length(ents[[1]]) <= 1 ||
       length(rels[[1]]) <= 1) {
        stop("Please make sure that the provied ents and rels tables are data.frames")
    }
    if(class(enrichment) == "data.frame" &&
       class(DGEs) == "data.frame") {
        print("Data type detected")
        createCytoGraphHelper(enrichment, ents, rels, DGEs, p.thresh=p.thresh,
                              fc.thresh = fc.thresh, numProt=numProt, ids=ids,
                              numTargets=numTargets)
    }
    else if(class(enrichment) == "list" &&
            class(enrichment[[1]]) == "list" &&
            class(DGEs) == "list") {
        print("Data type detected")
        lapply(1:length(enrichment), function(x) {
            lapply(1:length(DGEs), function(y) {
                createCytoGraphHelper(enrichment = enrichment[[x]][[y]],
                                      ents = ents, rels = rels, DGE = DGEs[[y]],
                                      p.thresh = p.thresh, fc.thresh = fc.thresh,
                                      method = names(enrichment)[x],
                                      condition = names(enrichment[[x]])[y],
                                      numProt = numProt, ids=ids,
                                      numTargets=numTargets) } ) } )
    }
    else if(class(enrichment) == "list" &&
            class(enrichment[[1]]) == "data.frame" &&
            class(DGEs) == "list") {
        print("Data type detected")
        lapply(1:length(enrichment), function(x) {
            createCytoGraphHelper(enrichment = enrichment[[x]],
                                  ents = ents, rels = rels, p.thresh = p.thresh,
                                  fc.thresh=fc.thresh, DGE= DGEs[[x]],
                                  condition=names(enrichment)[x], numProt=numProt, ids=ids,
                                  numTargets=numTargets) }  )
    }
    else if(class(enrichment) == "list" &&
            class(enrichment[[1]]) == "data.frame" &&
            class(DGEs) == "data.frame") {
        print("Data type detected")
        lapply(1:length(enrichment), function(x) {
            createCytoGraphHelper(enrichment = enrichment[[x]],
                                  ents = ents, rels = rels, p.thresh = p.thresh,
                                  fc.thresh=fc.thresh, DGE= DGEs,
                                  method=names(enrichment)[x], numProt=numProt,
                                  ids=ids, numTargets=numTargets) }  )
   }
}
createCytoGraphHelper <- function(enrichment, ents, rels, DGE,
                                  p.thresh, fc.thresh, method=NA,
                                  condition=NA, numProt, ids, numTargets) {

    print("Starting Analysis")
    if(!is.na(ids[1])) {
        sigProt <- enrichment$uid[ids]
    }
    else {
        sigProt <- enrichment$uid[1:numProt]
    }
    if(length(sigProt) == 0) {
        returnString <- paste("No significant proteins found.",
                              "For Method: ", method,
                              " and condition: ", condition)
        print(returnString)
        return
    }  else {
        returnString <- paste("Significant proteins found.",
                              "For Method: ", method,
                              " and condition: ", condition,
                              "Graphing...")
        print(returnString)


        ## Code written by Dr. Kourosh Zarringhalam
        pval.ind = grep('qval|q.val|q-val|q-val|P-value|P.value|pvalue|pval|Pval',
                        colnames(DGE), ignore.case = T)
        fc.ind = grep('fc|FC|fold|FoldChange', colnames(DGE), ignore.case = T)
        id.ind = grep('id|entr|Entrez', colnames(DGE), ignore.case = T)

        if(length(id.ind) == 0 | length(fc.ind) == 0 | length(pval.ind) == 0){
            stop('Please make sure the expression files column names are labled as entrez, fc, pvalue')
        }

        colnames(DGE)[pval.ind] <- 'pvalue'
        colnames(DGE)[fc.ind] <- 'foldchange'
        colnames(DGE)[id.ind] <- 'id'

        sigDGE <- DGE %>% filter(abs(foldchange) >= fc.thresh & pvalue <= p.thresh) %>%
            transmute(id = id, val = ifelse(foldchange > 0, 1, -1), pval = pvalue) %>%
            distinct(id, .keep_all = T)

        ## End Dr. Zarringhalam code
        ents.mRNA <- ents %>% dplyr::filter(type == "mRNA")
        sigDGE <- sigDGE %>% filter(id %in% ents.mRNA$id)
        sigEnts <- ents.mRNA %>% dplyr::filter(id %in% sigDGE$id) 
        
        sigRels <- rels[(rels$srcuid %in% sigProt), ]

        sigEnts <- sigEnts %>%
            dplyr::mutate(pVal = sigDGE$pval[sigDGE$id %in% sigEnts$id])

        sigEntsTempUIDs <- lapply(sigProt, function(x) {
           helpFuncTopbypVal(x, sigEnts, sigRels, numTargets) })

        sigDGE <- sigDGE %>%
            dplyr::mutate(uid = sigEnts$uid[sigEnts$id %in% sigDGE$id])

        sigEntsTempUIDs <- unique(unlist(sigEntsTempUIDs))
        sigEnts <- ents[ents$uid %in% sigEntsTempUIDs,]
        sigEnts <- sigEnts %>%
            dplyr::mutate(val = sigDGE$val[sigDGE$uid %in% sigEnts$uid])



        sigRels <- sigRels[sigRels$trguid %in% sigEnts$uid, ]
        sigEnts <- rbind(sigEnts, cbind(ents[ents$uid %in% sigProt,],
                                        val = NA))
 

        mRNAfc <- sigEnts$val[!is.na(sigEnts$val)]
        
        colorPal <- brewer.pal(11, "Spectral")
        type <- as.character(sigEnts$type)

        colorsNode <- sapply(1:length(type), function(x) {
          if(type[x] == "mRNA") {
            if(is.na(mRNAfc[x])) { "#7b7c7c" }
            else if(mRNAfc[x] == 1) { colorPal[2] }
            else if(mRNAfc[x] == 0) { "#FFFFFF" }
            else if(mRNAfc[x] == -1) { colorPal[10] }
          } else { colorPal[11] } } )

        edgeType <- sigRels$type
        colorsEdge <- sapply(1:nrow(sigRels), function(x) {
          if(edgeType[x]=="increase") { colorPal[9] }
          else if(edgeType[x] == "conflict") { "#8f9091" }
          else if(edgeType[x] == "decrease") { colorPal[3] }
        } )
        nodeD <- data.frame(id=as.character(sigEnts$uid),
                            name=sigEnts$name,
                            color=colorsNode,
                            stringsAsFactors=FALSE)

        edgeD <- data.frame(id = sigRels$uid,
                            source=as.character(sigRels$srcuid),
                            target=as.character(sigRels$trguid),
                            color = colorsEdge,
                            stringsAsFactors=FALSE)
        ## nodesToJSON <- makeJSONfromDF(nodeD)
        ## edgesToJSON <- makeJSONfromDF(edgeD) 
        
        ## network <- list()
        network <- createCytoscapeJsNetwork(nodeD, edgeD)
        
        rcytoscapejs(network$nodes, network$edges, showPanzoom=FALSE)
    }
}
makeJSONfromDF <- function(dataFrame) {
    tmpJSON <- sapply(1:nrow(dataFrame), function(x) {
        tmp <- sapply(colnames(dataFrame), function(y) {
            paste0(col, ":'", dataFrame[x, y], "'")
        })
        tmp <- paste(tmp, collapse= ", ")
        paste0("{ data: { ", tmp, "} }")
    })
    paste(tmpJSON, collapse=", ")
}
        
        
helpFuncTopbypVal <- function(sigProtein, sigEnts, sigRels, numTargets) {
  tarRels <- sigRels %>% dplyr::filter(srcuid == sigProtein)
  targs <- tarRels$trguid
  sigTarg <- targs[targs %in% sigEnts$uid]
  if(length(sigTarg) > numTargets) {
    sortTable <- sigEnts[sigEnts$uid %in% sigTarg, ] %>%
        dplyr::arrange(pVal) %>%
        dplyr::select(uid) 
    sortTable$uid[1:numTargets]
  }
  else{ sigTarg }
}
