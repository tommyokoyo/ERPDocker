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

# Install Frappe Bench
# RUN pip3 install frappe-bench
RUN python3 -m venv /home/frappe/venv && /home/frappe/venv/bin/pip install frappe-bench

# Set up working directory
WORKDIR /home/frappe

# Set environment variables for Python virtual environment
ENV PATH="/home/frappe/venv/bin:$PATH"

# Change ownership of the working directory
RUN chown -R frappe:frappe /home/frappe

# Switch to the frappe user before running bench
USER frappe

# Make sure Yarn is installed before running bench init
RUN yarn --version

RUN git clone https://github.com/tommyokoyo/frappe.git --branch develop frappe-source
RUN git clone https://github.com/tommyokoyo/erpnext.git --branch develop erpnext-source

# Now initialize Bench using the local cloned Frappe
RUN bench init --frappe-branch develop --skip-redis-config-generation frappe-bench

# Initialize Bench
# RUN bench init --frappe-branch version-15 frappe-bench

# Switch to Bench directory
WORKDIR /home/frappe/frappe-bench

RUN mv /home/frappe/erpnext-source apps/erpnext

# Clone custom Frappe and ERPNext repositories
# RUN rm -rf apps/frappe && rm -rf apps/erpnext
# RUN git clone https://github.com/tommyokoyo/frappe.git --branch develop apps/frappe
# RUN git clone https://github.com/tommyokoyo/erpnext.git --branch develop apps/erpnext

# Install Frappe & ERPNext inside Bench
RUN /home/frappe/venv/bin/pip install -e apps/frappe
RUN /home/frappe/venv/bin/pip install -e apps/erpnext

# Install additional required Python packages
RUN /home/frappe/venv/bin/pip install uuid uuid-utils

# Create a new site
RUN bench new-site erpnext.ekenya.co.ke --db-host mariadb --db-root-username root --db-root-password rootpassword --mariadb-root-password rootpassword

# Install ERPNext on the site
RUN bench --site erpnext.ekenya.co.ke install-app erpnext

# Build assets
RUN bench build
RUN bench clear-cache

# Expose ports for Nginx and Frappe
EXPOSE 8000 9000 3306

# Start Supervisor when the container starts
CMD ["bench", "start"]
