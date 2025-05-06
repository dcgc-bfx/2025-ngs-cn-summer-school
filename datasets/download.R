# Dataset provided by 10x: Visium HD Spatial Gene Expression Library, Mouse Brain (FFPE)
# https://www.10xgenomics.com/datasets/visium-hd-cytassist-gene-expression-libraries-of-mouse-brain-he

unlink("datasets/visiumhd_mouse_brain", recursive = TRUE)
dir.create("datasets/visiumhd_mouse_brain")

# Download spaceranger files
curl::curl_download(url = "https://cf.10xgenomics.com/samples/spatial-exp/3.0.0/Visium_HD_Mouse_Brain/Visium_HD_Mouse_Brain_web_summary.html",
                    destfile = "datasets/visiumhd_mouse_brain/web_summary.html")
curl::curl_download(url = "https://cf.10xgenomics.com/samples/spatial-exp/3.0.0/Visium_HD_Mouse_Brain/Visium_HD_Mouse_Brain_cloupe_008um.cloupe",
                    destfile = "datasets/visiumhd_mouse_brain/cloupe_008um.cloupe")
curl::curl_download(url = "https://cf.10xgenomics.com/samples/spatial-exp/3.0.0/Visium_HD_Mouse_Brain/Visium_HD_Mouse_Brain_feature_slice.h5",
                    destfile = "datasets/visiumhd_mouse_brain/feature_slice.h5")
curl::curl_download(url = "https://cf.10xgenomics.com/samples/spatial-exp/3.0.0/Visium_HD_Mouse_Brain/Visium_HD_Mouse_Brain_metrics_summary.csv",
                    destfile = "datasets/visiumhd_mouse_brain/metrics_summary.csv")
curl::curl_download(url = "https://cf.10xgenomics.com/samples/spatial-exp/3.0.0/Visium_HD_Mouse_Brain/Visium_HD_Mouse_Brain_molecule_info.h5",
                    destfile = "datasets/visiumhd_mouse_brain/molecule_info.h5")
curl::curl_download(url = "https://cf.10xgenomics.com/samples/spatial-exp/3.0.0/Visium_HD_Mouse_Brain/Visium_HD_Mouse_Brain_spatial.tar.gz",
                    destfile = "datasets/visiumhd_mouse_brain/spatial.tar.gz")
curl::curl_download(url = "https://cf.10xgenomics.com/samples/spatial-exp/3.0.0/Visium_HD_Mouse_Brain/Visium_HD_Mouse_Brain_binned_outputs.tar.gz",
                    destfile = "datasets/visiumhd_mouse_brain/binned_outputs.tar.gz")

# Unzip the tar.gz files
untar(tarfile = "datasets/visiumhd_mouse_brain/spatial.tar.gz")
unlink("datasets/visiumhd_mouse_brain/spatial.tar.gz")
file.rename(from = "spatial", to = "datasets/visiumhd_mouse_brain/spatial")

untar(tarfile = "datasets/visiumhd_mouse_brain/binned_outputs.tar.gz")
unlink("datasets/visiumhd_mouse_brain/binned_outputs.tar.gz")
file.rename(from = "binned_outputs", to = "datasets/visiumhd_mouse_brain/binned_outputs")


# Allen Brain Atlas from Seurat Visium HD vignette. Seurat object. Reduced to 200,000 cells (and rare cell types <25 cells have been removed).
curl::curl_download(url = "https://www.dropbox.com/scl/fi/r1mixf4eof2cot891n215/allen_scRNAseq_ref.Rds?rlkey=ynr6s6wu1efqsjsu3h40vitt7&dl=1",
                    destfile = "datasets/allen_scRNAseq_ref.Rds")
