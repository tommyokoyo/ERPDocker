# Use Debian as the base image
FROM debian:latest

# Define build-time arguments
ARG MARIADB_HOST
ARG MARIADB_PORT
ARG MARIADB_ERPNEXT_ROOT
ARG MARIADB_PASSWORD
ARG FRAPPE_ADMIN_PASSWORD

# Convert ARGs into ENV variables for later use in the container
ENV MARIADB_HOST=$MARIADB_HOST
ENV MARIADB_PORT=$MARIADB_PORT
ENV MARIADB_ERPNEXT_ROOT=$MARIADB_ERPNEXT_ROOT
ENV MARIADB_PASSWORD=$MARIADB_PASSWORD
ENV FRAPPE_ADMIN_PASSWORD=$FRAPPE_ADMIN_PASSWORD

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt update && apt install -y \
    python3 python3-venv python3-pip python3-dev \
    mariadb-client \
    redis \
    nodejs npm \
    supervisor \
    nginx \
    git \
    cron \
    && npm install -g yarn \
    && apt clean

# Create a non-root user
RUN useradd -m -s /bin/bash frappe

# Set up working directory
WORKDIR /home/frappe

# Create a venv and Install Frappe Bench
RUN python3 -m venv /home/frappe/venv && /home/frappe/venv/bin/pip install frappe-bench

# Set environment variables for the venv 
ENV PATH="$PATH:/home/frappe/venv/bin"

# Change ownership of the working directory
RUN chown -R frappe:frappe /home/frappe

# Switch to the frappe user before running bench
USER frappe

# Confirm Yarn is installed before running bench init
RUN yarn --version

# Now initialize Bench using the local cloned Frappe
RUN bench init frappe-bench

# Switch to Bench directory
WORKDIR /home/frappe/frappe-bench

# remove the installed frappe and replace with modifed one
RUN rm -r apps/frappe

# clone Frappe and erpnext into the apps folder (to change to gitlab)
RUN git clone https://github.com/tommyokoyo/frappe.git --depth 1 --branch develop apps/frappe

# Install Frappe
RUN /home/frappe/frappe-bench/env/bin/pip install -e apps/frappe

# build  frappe frontend dependacies
RUN yarn --cwd apps/frappe install --check-files

# Get and install erpnext
RUN bench get-app erpnext

# Remove original eprnext codebase
RUN rm -r apps/erpnext

# Configure buffer size for large downloads
RUN git config --global http.postBuffer 524288000

# Clone the modified codebase and replace with original codebase
RUN git clone https://github.com/tommyokoyo/erpnext.git --depth 1 --branch develop apps/erpnext

# Install erpnext dependacies
RUN /home/frappe/frappe-bench/env/bin/pip install -e apps/erpnext

# build the erpnext frontend dependacies
RUN yarn --cwd apps/erpnext install --check-files

# Create a new site with name erpnext.ekenya.co.ke
RUN bench new-site erpnext.ekenya.co.ke --db-host 192.168.202.138 \
        --db-root-username erpnext_admin \
        --db-root-password Security \
        --db-port 3306 \
        --admin-password Security

# Replace the default redis configuration
RUN echo '{ \
    "redis_cache": "redis://192.168.202.138:6379", \
    "redis_queue": "redis://192.168.202.138:6379", \
    "redis_socketio": "redis://192.168.202.138:6379" \
}' > /home/frappe/frappe-bench/sites/common_site_config.json

# Install erpnext application in the created site
RUN bench --site erpnext.ekenya.co.ke install-app erpnext

# Build frappe assets
RUN bench build

# Expose port
EXPOSE 8000

# Start the application when the container starts
CMD ["bench", "start"]
