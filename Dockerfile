# Use Debian as the base image
FROM debian:latest

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

# Change ownership of the working directory
#RUN chown -R frappe:frappe /home/frappe/frappe-bench/apps

# Switch to Bench directory
WORKDIR /home/frappe/frappe-bench

# remove the installed frappe and replace with modifed one
RUN rm -r apps/frappe

# clone Frappe and erpnext into the apps folder
RUN git clone https://github.com/tommyokoyo/frappe.git --depth 1 --branch develop apps/frappe
# RUN git clone https://github.com/tommyokoyo/erpnext.git --depth 1 --branch develop apps/erpnext

# Install Frappe & ERPNext dependacies
RUN /home/frappe/frappe-bench/env/bin/pip install -e apps/frappe

RUN yarn --cwd apps/frappe install --check-files

RUN bench get-app erpnext

RUN rm -r apps/erpnext

RUN git clone https://github.com/tommyokoyo/erpnext.git --depth 1 --branch develop apps/erpnext

RUN /home/frappe/frappe-bench/env/bin/pip install -e apps/erpnext

# build frontend dependacies
RUN yarn --cwd apps/erpnext install --check-files

# Create a new site
RUN bench new-site erpnextdemo.ekenya.co.ke --db-host 192.168.202.138 \
        --db-root-username erpnext_admin \
        --db-root-password Security \
        --db-port 3306 \
        --admin-password Security

# Fix Redis Configuration
RUN echo '{ \
    "redis_cache": "redis://192.168.202.138:6379", \
    "redis_queue": "redis://192.168.202.138:6379", \
    "redis_socketio": "redis://192.168.202.138:6379" \
}' > /home/frappe/frappe-bench/sites/common_site_config.json

RUN git config --global http.postBuffer 524288000
# RUN bench get-app erpnext apps/erpnext


# Install ERPNext on the site
RUN bench --site erpnextdemo.ekenya.co.ke install-app erpnext

# Build frappe assets
RUN bench build

# Expose port
EXPOSE 8000

# Start Supervisor when the container starts
CMD ["bench", "start"]
