#########################################################
# Installation script for the 2025 NGS-CN summer school #
#########################################################

# Specify repository for CRAN
options(CRAN='https://cloud.r-project.org')

# Install the pak package manager
install.packages('pak')

# Install the reticulate package for using python
pak::pkg_install('reticulate')

# Install python via miniconda
# By default, miniconda will be installed in a user directory so that no admin rights are needed. To use another location, set the environment variable RETICULATE_MINICONDA_PATH.
# To remove miniconda again, call reticulate::miniconda_uninstall().
library(reticulate)
reticulate::install_miniconda()

# This will install a miniconda environment for the course with the name '2025-ngs-cn-summer-school' and the required python packages.
# To remove environment again, call reticulate::conda_remove('2025-ngs-cn-summer-school').
reticulate::conda_create(envname='2025-ngs-cn-summer-school', 
  packages=c('leidenalg', 'anndata', 'scipy'),
  forge=TRUE
)
# options(rstudio.python.installationPath = "/path/to/python")

# Install all other R packages
pak::pkg_install('tidyverse')
