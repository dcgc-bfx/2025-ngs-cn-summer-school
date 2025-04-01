#!/bin/sh
#SBATCH --time=08:00:00
#SBATCH --signal=USR2
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=8192
#SBATCH --output=/home/sequencing/andpetzo/rstudio-server-how-to-login.txt
#SBATCH --error=/home/sequencing/andpetzo/rstudio-server-errors.txt
#SBATCH --job-name=andpetzo
#SBATCH --partition=ngs.q
#SBATCH --nodelist=compute-2-3

###################################
# USER-SPECIFIC SETTINGS (CHANGE) #
###################################

# TODO:
# - adjust resources
# - start job as user1, run rstudio as user2
# - adjust/fix singularity image path

# Distribute across compute nodes

# Set the compute node (needs to be the same as above in nodelist)
COMPUTE_NODE=compute-2-3

# Set the user login (needs to be the same as above in output, error and job-name
USER=USER

# Set a generic password
PASSWORD=abba

# Set a port between 9000 and 9025
PORT=9001

# Set path/url to Singularity image
SINGULARITY_IMAGE=/group/sequencing/bfx/scripts/andreasp/2025-ngs-cn-summer-school/singularity/Singularity.sif

########################################################################
# COPIED/ADAPTED FROM: https://rocker-project.org/use/singularity.html #
########################################################################

# Create a unique temporary directory for this job
workdir=$(mktemp -p /tmp  -d)

# Set up the cleanup trap
trap "rm -rf ${workdir}" EXIT

# This is the working directory for r-server/singularity
mkdir ${workdir}/rserver

# This is the temp directory for this job
mkdir ${workdir}/tmp

# Set R_LIBS_USER to an existing path specific to rocker/rstudio to avoid conflicts with
# personal libraries from any R installation in the host environment

cat > ${workdir}/rserver/rsession.sh <<"END"
#!/bin/sh
export R_LIBS_USER=${HOME}/R/rstudio-server/4.4.2
mkdir -p "${R_LIBS_USER}"
## custom Rprofile & Renviron (default is $HOME/.Rprofile and $HOME/.Renviron)
# export R_PROFILE_USER=/path/to/Rprofile
# export R_ENVIRON_USER=/path/to/Renviron
exec /usr/lib/rstudio-server/bin/rsession "${@}"
END

chmod +x ${workdir}/rserver/rsession.sh

# Do not suspend idle sessions.
# Alternative to setting session-timeout-minutes=0 in /etc/rstudio/rsession.conf
# https://github.com/rstudio/rstudio/blob/v1.4.1106/src/cpp/server/ServerSessionManager.cpp#L126
export RSTUDIO_SESSION_TIMEOUT=0

# Print message with instructions
cat <<END
1. SSH tunnel from your workstation using the following command:

   ssh -N -L 8787:${COMPUTE_NODE}:${PORT} ${USER}@${COMPUTE_NODE}

   and point your web browser to http://localhost:8787

2. log in to RStudio Server using the following credentials:

   user: ${USER}
   password: ${PASSWORD}

When done using RStudio Server, terminate the job by:

1. Exit the RStudio Session ("power" button in the top right corner of the RStudio window)
2. Issue the following command on the login node:

      scancel -f ${SLURM_JOB_ID}
END

# Load singularity and set variables that should be exported
module load apps/singularity

export SINGULARITYENV_USER=$USER
export SINGULARITYENV_PASSWORD=$PASSWORD
export SINGULARITYENV_PORT=$PORT
export SINGULARITYENV_RSTUDIO_SESSION_TIMEOUT=0

# Start R-Server
singularity exec --cleanenv \
                 --scratch /run,/var/lib/rstudio-server \
                 --workdir ${workdir}/rserver \
		 --bind ${workdir}/rserver/rsession.sh:/etc/rstudio/rsession.sh \
		 --bind ${workdir}/tmp:/tmp \
                 ${SINGULARITY_IMAGE} \
    rserver --www-port ${PORT} \
            --auth-none=0 \
            --auth-pam-helper-path=pam-helper \
            --auth-stay-signed-in-days=30 \
            --auth-timeout-minutes=0 \
            --server-user=${USER} \
	    --rsession-path=/etc/rstudio/rsession.sh

printf 'rserver exited'
