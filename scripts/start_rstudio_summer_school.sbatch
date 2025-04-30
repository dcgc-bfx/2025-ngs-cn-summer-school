#!/bin/sh
#SBATCH --time=96:00:00
#SBATCH --signal=B:SIGUSR1@300
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --mem=64000
#SBATCH --output=rstudio_summer_school_login.txt
#SBATCH --error=rstudio_summer_school_errors.txt
#SBATCH --job-name=ngscnsummerschool
#SBATCH --partition=ngs.q
#SBATCH --nodelist=compute-2-3            

# Note for IT:        
# Take this script and adapt it for all users (line 9-11)
# Also adapt login information and port (line 21-28)

# Note for us: 
# Git clone repository
# Download data
# Create Rstudio project
# Add download link for sif

###################################                       
# USER-SPECIFIC SETTINGS (CHANGE) #
###################################
                    
# Set the user login (needs to be the same as above in output, error and job-name
USER=$(whoami)

# Set a generic password
PASSWORD=$(openssl rand -base64 8)

# Set a port between 9000 and 9025
PORT=9002

# Set path/url to Singularity image
SINGULARITY_IMAGE=oras://gcr.hrz.tu-chemnitz.de/dcgc-bfx/singularity/singularity-single-cell:Unstable

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
	kill -s SIGTERM 0

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
1. Create an SSH tunnel from your laptop to our biocluster4 head node

   ssh  -o ServerAliveInterval=300 -N -L ${PORT}:localhost:${PORT} ${USER}@biocluster4

2. Open your web browser and point it to http://localhost:${PORT}

3. Log into RStudio Server using the following credentials:

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

# Start R-Server
singularity exec \
  --cleanenv \
  --scratch /run,/var/lib/rstudio-server \
  --workdir ${workdir}/singularity \
  --bind ${workdir}/tmp \
  --bind ${workdir}/rserver \
  ${SINGULARITY_IMAGE} \
  micromamba run --name single-cell /usr/lib/rstudio-server/bin/rserver --server-user=${USER} --www-port=${PORT} &

#  Tunnel back to biocluster4 with ssh
ssh -o ServerAliveInterval=300 -N -R ${PORT}:localhost:${PORT} biocluster4

printf 'rserver exited'
