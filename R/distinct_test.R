#' Test for differential state between two groups of samples, based on scRNA-seq data.
#'
#' \code{distinct_test} tests for differential state between two groups of samples.
#' 
#' @param x a \code{linkS4class{SummarizedExperiment}} or a \code{linkS4class{SingleCellExperiment}} object.
#' @param name_assays_expression a character ("logcounts" by default), 
#' indicating the name of the assays(x) element which stores the expression data (i.e., assays(x)$name_assays_expression).
#' We strongly encourage using normalized data, such as counts per million (CPM) or log2-CPM (e.g., 'logcounts' as created via \code{scater::logNormCounts}).
#' In case additional covariates are provided (e.g., batch effects), we highly recommend using log-normalized data, such as log2-CPM (e.g., 'logcounts' as created via \code{scater::logNormCounts}).
#' @param name_cluster a character ("cluster_id" by default), 
#' indicating the name of the colData(x) element which stores the cluster id of each cell (i.e., colData(x)$name_cluster).
#' @param name_sample a character ("sample_id" by default), 
#' indicating the name of the colData(x) element which stores the sample id of each cell (i.e., colData(x)$name_sample).
#' @param design a \code{\linkS4class{matrix}} or \code{\linkS4class{data.frame}} with the design matrix of the study (e.g., built via model.matrix(~batches), 
#' design must contain one row per sample, while columns include intercept, group and eventual covariates such as batches.
#' Row names of design must indicate the sample ids, and correspond to the names in colData(x)$name_sample.
#' @param column_to_test indicates the column(s) of the design one wants to test (do not include the intercept).
#' @param P_1 the number of permutations to use on all gene-cluster combinations.
#' @param P_2  the number of permutations to use, when a (raw) p-value is < 0.1 (500 by default).
#' @param P_3  the number of permutations to use, when a (raw) p-value is < 0.01 (2,000 by default).
#' @param P_4  the number of permutations to use, when a (raw) p-value is < 0.001 (10,000 by default).
#' In order to obtain a finer ranking for the most significant genes,
#' if computational resources are available, we encourage users to set P_4 = 20,000.
#' @param N_breaks the number of breaks at which to evaluate the comulative density function.
#' @param min_non_zero_cells the minimum number of non-zero cells (across all samples) in each cluster for a gene to be evaluated.
#' @param n_cores the number of cores to parallelize the tasks on (parallelization is at the cluster level: each cluster is parallelized on a thread).
#' @return A \code{\linkS4class{data.frame}} object.
#' Columns `gene` and `cluster_id` contain the gene and cell-cluster name, while `p_val`, `p_adj.loc` and `p_adj.glb` report the raw p-values, locally and globally adjusted p-values, via Benjamini and Hochberg (BH) correction.
#' In locally adjusted p-values (`p_adj.loc`) BH correction is applied in each cluster separately, while in globally adjusted p-values (`p_adj.glb`) BH correction is performed to the results from all clusters.
#' Column `filtered` indicates whether a gene-cluster result was filtered (if TRUE), or analyzed (if FALSE).
#' A gene-cluster combination is filtered when fewer than `min_non_zero_cells` non-zero cells are available.
#' Filtered results have raw and adjusted p-values equal to 1.
#' @examples
#' # load the input data:
#' data("Kang_subset", package = "distinct")
#' Kang_subset
#' 
#' # create the design of the study:
#' samples = Kang_subset@metadata$experiment_info$sample_id
#' group = Kang_subset@metadata$experiment_info$stim
#' design = model.matrix(~group)
#' # rownames of the design must indicate sample ids:
#' rownames(design) = samples
#' design
#' 
#' # Note that the sample names in `colData(x)$name_sample` have to be the same ones as those in `rownames(design)`.
#' rownames(design)
#' unique(SingleCellExperiment::colData(Kang_subset)$sample_id)
#' 
#' # In order to obtain a finer ranking for the most significant genes, if computational resources are available, we encourage users to increase P_4 (i.e., the number of permutations when a raw p-value is < 0.001) and set P_4 = 20,000 (by default P_4 = 10,000).
#' 
#' # The group we would like to test for is in the second column of the design, therefore we will specify: column_to_test = 2
#' 
#' set.seed(61217)
#' res = distinct_test(
#'   x = Kang_subset, 
#'   name_assays_expression = "logcounts",
#'   name_cluster = "cell",
#'   design = design,
#'   column_to_test = 2,
#'   min_non_zero_cells = 20,
#'   n_cores = 2)
#' 
#' # We can optionally add the fold change (FC) and log2-FC between groups:
#' res = log2_FC(res = res,
#'   x = Kang_subset, 
#'   name_assays_expression = "cpm",
#'   name_group = "stim",
#'   name_cluster = "cell")
#' 
#' # Visualize significant results:
#' head(top_results(res))
#' 
#' # Visualize significant results from a specified cluster of cells:
#' top_results(res, cluster = "Dendritic cells")
#' 
#' # By default, results from 'top_results' are sorted by (globally) adjusted p-value;
#' # they can also be sorted by log2-FC:
#' top_results(res, cluster = "Dendritic cells", sort_by = "log2FC")
#' 
#' # Visualize significant UP-regulated genes only:
#' top_results(res, up_down = "UP",
#'   cluster = "Dendritic cells")
#' 
#' # Plot density and cdf for gene 'ISG15' in cluster 'Dendritic cells'.
#' plot_densities(x = Kang_subset,
#'   gene = "ISG15",
#'   cluster = "Dendritic cells",
#'   name_assays_expression = "logcounts",
#'   name_cluster = "cell",
#'   name_sample = "sample_id",
#'   name_group = "stim")
#'  
#'  plot_cdfs(x = Kang_subset,
#'    gene = "ISG15",
#'    cluster = "Dendritic cells",
#'    name_assays_expression = "logcounts",
#'    name_cluster = "cell",
#'    name_sample = "sample_id",
#'    name_group = "stim")
#' 
#' @author Simone Tiberi \email{simone.tiberi@uzh.ch}
#' 
#' @seealso \code{\link{plot_cdfs}}, \code{\link{plot_densities}}, \code{\link{log2_FC}}, \code{\link{top_results}}
#' 
#' @export
distinct_test = function(x, 
                         name_assays_expression = "logcounts",
                         name_cluster = "cluster_id",
                         name_sample = "sample_id",
                         design, # design matrix
                         column_to_test = 2,
                         P_1 = 100, 
                         P_2 = 500, 
                         P_3 = 2000, 
                         P_4 = 10000, 
                         N_breaks = 25, 
                         min_non_zero_cells = 20,
                         n_cores = 1){
  stopifnot(
    ( is(x, "SummarizedExperiment") | is(x, "SingleCellExperiment") ),
    is.character(name_assays_expression), length(name_assays_expression) == 1L,
    is.character(name_cluster), length(name_cluster) == 1L,
    is.character(name_sample), length(name_sample) == 1L,
    is.matrix(design) | is.data.frame(design),
    is.numeric(column_to_test), length(column_to_test) > 0L,
    is.numeric(P_1), length(P_1) == 1L,
    is.numeric(P_2), length(P_2) == 1L,
    is.numeric(P_3), length(P_3) == 1L,
    is.numeric(P_4), length(P_4) == 1L,
    is.numeric(N_breaks), length(N_breaks) == 1L,
    is.numeric(min_non_zero_cells), length(min_non_zero_cells) == 1L,
    is.numeric(n_cores), length(n_cores) == 1L
  )
  
  # check P's are in a non-decreasing order:
  if( (P_1 > P_2) | (P_2 > P_3) | (P_3 > P_4) ){
    message("The number of permutations `P_x` must be in a non-decreasing order: P_1 <= P_2 <= P_3 <= P_4")
    return(NULL)
  }
  
  # check for NA's:
  if(any(is.na(design)) | any(is.null(design)) | any(is.nan(design))){
    message("'design' contains NA, NULL or NaN values")
    return(NULL)
  }
  
  if(!is.fullrank(design)){ # if the matrix is NOT full rank:
    message("'design' is not full rank")
    return(NULL)
  }
  
  # lower-bound for min_non_zero_cells:
  if(min_non_zero_cells < 0){
    message("'min_non_zero_cells' must be at least 0")
    return(NULL)
  }
  
  # count matrix:
  sel = which(names(assays(x)) == name_assays_expression)
  if( length(sel) == 0 ){
    message("'", name_assays_expression, "' not found in names(assays(x))")
    return(NULL)
  }
  if( length(sel) > 1 ){
    message("'", name_assays_expression, "' found multiple times in names(assays(x))")
    return(NULL)
  }
  counts = assays(x)[[sel]]
  
  if(any(is.na(counts)) | any(is.null(counts)) ){
    message("'assays(x)$", name_assays_expression,"' contains NA or NULL values")
    return(NULL)
    # OR: message("These values will be removed in differentiala anlyses")
    # To allow for NAs -> edit C++ scripts, by remove NAs for each gene (in gene loop), and editing indeces
  }
  # remove rows with 0 counts:
  if(nrow(counts) > 1.5){ # only if more than 1 gene (row): otherwise matrix is transformed into a vector
    counts = counts[ rowSums(counts > 0) > 0, ]
  }
  
  # check if counts are sparse matrix: if not, turn counts intro Sparce object:
  if(!is(counts, "dgCMatrix")){
    counts = Matrix(data=counts, 
                    sparse = TRUE)
  }
  
  # cluster ids:
  sel = which(names(colData(x)) == name_cluster)
  if( length(sel) == 0 ){
    message("'", name_cluster,"' not found in names(colData(x))")
    return(NULL)
  }
  if( length(sel) > 1 ){
    message("'", name_cluster,"' found multiple times in names(colData(x))")
    return(NULL)
  }
  cluster_ids = factor(colData(x)[[sel]])
  n_clusters = nlevels(cluster_ids)
  cluster_ids_num = as.numeric(cluster_ids)-1
  
  # sample ids:
  sel = which(names(colData(x)) == name_sample)
  if( length(sel) == 0 ){
    message("'", name_sample,"' not found in names(colData(x))")
    return(NULL)
  }
  if( length(sel) > 1 ){
    message("'", name_sample,"' found multiple times in names(colData(x))")
    return(NULL)
  }
  sample_ids = factor(colData(x)[[sel]])
  
  nas = is.na(sample_ids) | is.null(sample_ids) | is.nan(sample_ids) | is.na(cluster_ids) | is.null(cluster_ids) | is.nan(cluster_ids)
  if(any(nas)){
    message("NAs, NULL or NaN found in 'colData(x)$",name_sample,"' and/or 'colData(x)$",name_cluster,"': removing corresponding cells")
    sample_ids  = sample_ids[!nas]
    cluster_ids_num = cluster_ids_num[!nas]
    counts = counts[,!nas]
  }
  
  # check if ALL samples names from rownames(design) are present in sample_ids
  # maybe allow for samples to be present in sample_ids but not in rownames(design) ?
  if( ! all(rownames(design) %in% sample_ids)){
    message("All samples names in 'rownames(design)' must be present in 'colData(x)$",name_sample,"'")
    return(NULL)
  }
  if( ! all(sample_ids %in% rownames(design))){
    message("All samples names in 'colData(x)$",name_sample,"' must be present in 'rownames(design)'")
    return(NULL)
  }
  
  # sample ids:
  sample_ids = factor(sample_ids, levels = rownames(design)) # keep the order in design
  n_samples = nlevels(sample_ids)
  sample_ids_num = as.numeric(sample_ids)-1
  
  # group ids (1 per cell)
  if(ncol(design) < column_to_test){
    message("'column_to_test' cannot be bigger than 'ncol(design)'")
    return(NULL)
  }
  
  # extract group ids from experiment_info:
  group_ids_of_samples = apply(as.matrix(design[,column_to_test]), 1, paste, collapse = ".")
  group_ids_of_samples = as.numeric(factor(group_ids_of_samples))
  
  groups = unique(group_ids_of_samples)
  n_samples_per_group = vapply( groups, function(g) sum(group_ids_of_samples == g), FUN.VALUE = numeric(1) )
  # n_samples_per_group contains the samples of each group (e.g., 3 2)
  n_samples_per_group_per_sample = n_samples_per_group[match(group_ids_of_samples,groups)]
  # n_samples_per_group_per_sample contains the samples of each group that samples belong to, (e.g., 3 3 3 2 2) 
  
  n_groups = length(groups)
  
  message(paste0(n_groups, " groups of samples provided"))
  
  if(n_groups < 1.5){
    message("One group only detected; at least 2 groups are needed to perform differential testing between groups")
    return(NULL)
  }
  
  # remove columns to test from the design:
  design_covar = design[,-column_to_test]
  
  # check if design matrix, without covariates columns still has > 1 column (i.e., not only the intercept):
  cond_covariates = ncol(design) - length(column_to_test) > 1.5 
  if( cond_covariates ){ # 2-group WITH COVARIATES:
    message("Covariates detected")
  }
  
  message("Data loaded, starting differential testing")
  
  if(n_groups > 2.5){
    message("At most 2 groups should be provided.")
    message("To compare more than 2 groups, perform pairwise testing between pairs of groups.")
    return(NULL)
  }else{
    if( cond_covariates ){ # 2-group WITH COVARIATES:
      
      if(n_cores > 1){
        # call a R wrapper, that parallelizes Rcpp code from R:
        p_val = perm_test_parallel_covariates_R(P_1, # number of permutations
                                                P_2,
                                                P_3,
                                                P_4,
                                                N_breaks, # number of breaks at which to evaluate the cdf
                                                cluster_ids_num, # ids of clusters (cell-population) for every cell
                                                sample_ids_num, # ids of samples for every cell
                                                n_samples, # total number of samples
                                                group_ids_of_samples, # ids of groups (1 or 2) for every sample
                                                min_non_zero_cells, # min number of cells with > 0 expression in each group
                                                t(counts), 
                                                n_cores,
                                                as.matrix(design_covar))
      }else{
        # call non-parallel Rcpp code:
        p_val = .Call(`_distinct_perm_test_covariates`,
                      P_1, # number of permutations
                      P_2,
                      P_3,
                      P_4,
                      N_breaks, # number of breaks at which to evaluate the cdf
                      cluster_ids_num, # ids of clusters (cell-population) for every cell
                      n_clusters, # total number of clusters
                      sample_ids_num, # ids of samples for every cell
                      n_samples, # total number of samples
                      group_ids_of_samples, # ids of groups (1 or 2) for every sample
                      min_non_zero_cells, # min number of cells with > 0 expression in each group
                      t(counts),
                      as.matrix(design_covar))[[1]] # [[1]]: results returned as a 1 element list
      }
    }else{ # 2-group:
      if(n_cores > 1){
        # call a R wrapper, that parallelizes Rcpp code from R:
        p_val = perm_test_parallel_R(P_1, # number of permutations
                                     P_2,
                                     P_3,
                                     P_4,
                                     N_breaks, # number of breaks at which to evaluate the cdf
                                     cluster_ids_num, # ids of clusters (cell-population) for every cell
                                     sample_ids_num, # ids of samples for every cell
                                     n_samples, # total number of samples
                                     group_ids_of_samples, # ids of groups (1 or 2) for every sample
                                     min_non_zero_cells, # min number of cells with > 0 expression in each group
                                     t(counts), 
                                     n_cores)
      }else{
        # call non-parallel Rcpp code:
        p_val = .Call(`_distinct_perm_test`,
                      P_1, # number of permutations
                      P_2,
                      P_3,
                      P_4,
                      N_breaks, # number of breaks at which to evaluate the cdf
                      cluster_ids_num, # ids of clusters (cell-population) for every cell
                      n_clusters, # total number of clusters
                      sample_ids_num, # ids of samples for every cell
                      n_samples, # total number of samples
                      group_ids_of_samples, # ids of groups (1 or 2) for every sample
                      min_non_zero_cells, # min number of cells with > 0 expression in each group
                      t(counts) )[[1]] # [[1]]: results returned as a 1 element list
      }
    }
  }
  
  message("Differential testing completed, returning results")
  
  # store results which were filtered (due min_non_zero_cells filter)
  filtered = (p_val == -1)
  
  # set -1s to NA, so that we don't use these elements when adjusting p-values:
  p_val[ p_val == -1 ] = NA
  
  # locally adjusted p-values:
  res_adjusted_locally = apply(p_val, 2, p.adjust, method = "BH")
  
  filtered = c(filtered)
  p_val = c(p_val)
  res_adjusted_locally = c(res_adjusted_locally)
  # globally adjusted p-values:
  res_adjusted_globally = p.adjust(p_val, method = "BH")
  
  gene_names = rownames(counts)
  if(is.null(gene_names)){
    gene_names = seq_len(nrow(counts))
  }
  
  res = data.frame(
    gene = rep(gene_names, times = n_clusters),
    cluster_id = rep( levels(cluster_ids), each = nrow(counts) ),
    p_val = p_val,
    p_adj.loc = res_adjusted_locally,
    p_adj.glb = res_adjusted_globally,
    filtered = filtered
  )
  
  # set to 1 pvals (and adjusted pvals) which were NA (not analyzed:)
  res$p_val[is.na(res$p_val)] = 1
  res$p_adj.loc[is.na(res$p_adj.loc)] = 1
  res$p_adj.glb[is.na(res$p_adj.glb)] = 1
  
  res
}
