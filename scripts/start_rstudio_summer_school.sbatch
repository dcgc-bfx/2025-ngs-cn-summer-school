#!/bin/sh
#SBATCH --time=24:00:00
#SBATCH --signal=B:SIGUSR1@120
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --mem=64000
#SBATCH --output=rstudio_summer_school_login.txt
#SBATCH --error=rstudio_summer_school_errors.txt
#SBATCH --job-name=ngscn
#SBATCH --partition=ngs.q
#SBATCH --nodelist=compute-2-3
#
# send the SIGUSR1 signal 300 seconds before end of the time limit
#SBATCH --signal=B:SIGUSR1@300

# Distribute across compute nodes

###################################
# USER-SPECIFIC SETTINGS (CHANGE) #
###################################

# TODO:
# - adjust resources
# - start job as user1, run rstudio as user2
# - adjust/fix singularity image path

# Set the user login (needs to be the same as above in output, error and job-name
USER=$(whoami)

# Set a generic password
PASSWORD=$(openssl rand -base64 8)

# Set a port between 9000 and 9025
PORT=9001

# Set path/url to Singularity image
#SINGULARITY_IMAGE=oras://gcr.hrz.tu-chemnitz.de/dcgc-bfx/singularity/singularity-single-cell:Unstable
SINGULARITY_IMAGE=/group/sequencing/bfx/scripts/andreasp/2025-ngs-cn-summer-school/singularity/singularity-single-cell_Unstable.sif

########################################################################
# COPIED/ADAPTED FROM: https://rocker-project.org/use/singularity.html #
########################################################################

# Fail when error
set -ef -o pipefail

# Create a unique temporary directory for this job
workdir=$(mktemp -p /tmp  -d summer_school.XXXXXXXXXX)

# 300s before end of the job, slurm sends the signal SIGUSR1. If a job is canceled, slurm sends the signal SIGTERM. 
# Intercept these signals, then run this function to shut down the job gracefully.
function shutdown()
{
	# Undo trap
	trap " " SIGUSR1 SIGTERM

	# Terminate all child processes
	kill 0

	# Wait until done
	wait

	# Remove working directory
	rm -rf "${workdir}"
}

# associate the function "sig_handler_USR1" with the USR1 signal
trap 'shutdown' SIGUSR1 SIGTERM

# This is the working directory for singularity
mkdir ${workdir}/singularity

# This is the working directory for the R server
mkdir ${workdir}/rserver

# This is the temp directory for computations in R
mkdir ${workdir}/tmp

# Host name
COMPUTE_NODE=$(hostname | sed 's/.biocluster$//')

# Print message with instructions
cat <<END
1. SSH tunnel from your workstation using the following command:

   ssh  -o ServerAliveInterval=300 -N -L ${PORT}:localhost:${PORT} ${USER}@biocluster4

   and point your web browser to http://localhost:${PORT}

2. log in to RStudio Server using the following credentials:

   user: ${USER}
   password: ${PASSWORD}

When done using RStudio Server, terminate the job by:

1. Exit the RStudio Session ("power" button in the top right corner of the RStudio window)
2. Issue the following command on the login node:

      scancel ${SLURM_JOB_ID}
END



# Load singularity and set variables that should be exported from host environment
module load apps/singularity

export SINGULARITYENV_RSTUDIO_USER=${USER}
export SINGULARITYENV_RSTUDIO_PASSWORD=${PASSWORD}
export SINGULARITYENV_RSTUDIO_PORT=${PORT}
export SINGULARITYENV_RSTUDIO_SESSION_TIMEOUT=0

# Tunnel back to biocluster4 with ssh (runs in background) and start R-Server (runs in foreground). 
# Start R-Server
ssh -o ServerAliveInterval=300 -N -R ${PORT}:localhost:${PORT} biocluster4 & \
singularity exec --cleanenv \
                 --scratch /run,/var/lib/rstudio-server \
                 --workdir ${workdir}/singularity \
		 --bind ${workdir}/tmp \
		 --bind ${workdir}/rserver \
                 ${SINGULARITY_IMAGE} \
	micromamba run --name single-cell /usr/lib/rstudio-server/bin/rserver --server-user=${USER} --www-port=${PORT}

printf 'rserver exited'
