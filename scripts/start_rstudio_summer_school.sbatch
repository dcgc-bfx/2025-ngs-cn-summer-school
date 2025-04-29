#!/bin/sh
#SBATCH --time=24:00:00
#SBATCH --signal=B:SIGUSR1@300
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=24000
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
PASSWORD=notsafe

# Set a port between 9000 and 9025
PORT=9002

# Set path/url to Singularity image
SINGULARITY_IMAGE=singularity.sif

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

export SINGULARITYENV_USER=${USER}
export SINGULARITYENV_PASSWORD=${PASSWORD}
export SINGULARITYENV_PORT=${PORT}
export SINGULARITYENV_RSTUDIO_SESSION_TIMEOUT=0
export SINGULARITYENV_R_ENVIRON_USER=${R_ENVIRON_USER}

# Tunnel back to biocluster4 with ssh (runs in background) and start R-Server (runs in foreground). 
# Start R-Server
ssh -o ServerAliveInterval=300 -N -R ${PORT}:localhost:${PORT} biocluster4 & \
singularity exec --contain \
		 --cleanenv \
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
