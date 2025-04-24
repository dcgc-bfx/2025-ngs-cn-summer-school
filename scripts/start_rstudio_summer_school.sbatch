#!/bin/sh
#SBATCH --time=24:00:00
#SBATCH --signal=B:SIGUSR1@120
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=24000
#SBATCH --output=rstudio_summer_school_login.txt
#SBATCH --error=rstudio_summer_school_errors.txt
#SBATCH --job-name=andpetzo
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
USER=andpetzo

# Set a generic password
PASSWORD=notsafe

# Set a port between 9000 and 9025
PORT=9001

# Set path/url to Singularity image
SINGULARITY_IMAGE=/group/sequencing/bfx/scripts/andreasp/2025-ngs-cn-summer-school/singularity/Singularity.sif

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

# Create a custom user .Renviron file (contains environment variables for R) for this session
if [ -f ${HOME}/.Renviron ]
then
  cp ${HOME}/.Renviron ${workdir}/rserver/.Renviron
else
  touch ${workdir}/rserver/.Renviron
fi
export R_ENVIRON_USER=${workdir}/rserver/.Renviron

# Create custom directory for user-installed libraries and add to .Renviron file
R_LIBS_USER="${HOME}/R/start_rstudio_summer_school/%p-library/%v"
mkdir -p "${HOME}/R/start_rstudio_summer_school"
echo "R_LIBS_USER=${R_LIBS_USER}" >> ${workdir}/rserver/.Renviron

# Create a custom rsession.sh script that will be 
cat > ${workdir}/rserver/rsession.sh <<END
#!/bin/sh

# Set temp directory
export TMPDIR="${workdir}/tmp"

# Export user Renviron
export R_ENVIRON_USER="${R_ENVIRON_USER}"
exec /usr/lib/rstudio-server/bin/rsession "\${@}"
END

chmod +x ${workdir}/rserver/rsession.sh


# Do not suspend idle sessions.
# Alternative to setting session-timeout-minutes=0 in /etc/rstudio/rsession.conf
# https://github.com/rstudio/rstudio/blob/v1.4.1106/src/cpp/server/ServerSessionManager.cpp#L126
export RSTUDIO_SESSION_TIMEOUT=0

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

export SINGULARITYENV_USER=${USER}
export SINGULARITYENV_PASSWORD=${PASSWORD}
export SINGULARITYENV_PORT=${PORT}
export SINGULARITYENV_RSTUDIO_SESSION_TIMEOUT=0
export SINGULARITYENV_R_ENVIRON_USER=${R_ENVIRON_USER}

# Tunnel back to biocluster4 with ssh (runs in background) and start R-Server (runs in foreground). 
# Start R-Server
ssh -o ServerAliveInterval=300 -N -R ${PORT}:localhost:${PORT} biocluster4 & \
singularity exec --cleanenv \
                 --scratch /run,/var/lib/rstudio-server \
                 --workdir ${workdir}/singularity \
		 --bind ${workdir}/tmp \
		 --bind ${workdir}/rserver \
		 --bind ${workdir}/rserver/rsession.sh:/etc/rstudio/rsession.sh \
                 ${SINGULARITY_IMAGE} \
    rserver --www-port ${PORT} \
            --auth-none=0 \
            --auth-pam-helper-path=pam-helper \
            --auth-stay-signed-in-days=30 \
            --auth-timeout-minutes=0 \
            --server-user=${USER} \
	    --rsession-path=/etc/rstudio/rsession.sh

printf 'rserver exited'
