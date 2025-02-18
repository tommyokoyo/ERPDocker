# Use Debian as the base image
FROM debian:latest

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt update && apt install -y \
    python3 python3-pip python3-dev \
    mariadb-client \
    redis \
    nodejs npm \
    supervisor \
    nginx \
    git \
    && apt clean

# Install Frappe Bench
RUN pip3 install frappe-bench

# Set up working directory
WORKDIR /home/frappe

# Initialize Bench
RUN bench init --frappe-branch version-15 frappe-bench

# Switch to Bench directory
WORKDIR /home/frappe/frappe-bench

# Clone custom Frappe and ERPNext repositories
RUN rm -rf apps/frappe && rm -rf apps/erpnext
RUN git clone https://github.com/tommyokoyo/frappe.git --branch version-15 apps/frappe
RUN git clone https://github.com/tommyokoyo/erpnext.git --branch version-15 apps/erpnext

# Install Frappe & ERPNext
RUN pip install -e apps/frappe
RUN pip install -e apps/erpnext

# Create a new site
RUN bench new-site erpnext.ekenya.co.ke --db-host mariadb --db-root-username root --db-root-password rootpassword

# Install ERPNext on the site
RUN bench --site erpnext.ekenya.co.ke install-app erpnext

# Build assets
RUN bench build
RUN bench clear-cache

# Expose ports for Nginx and Frappe
EXPOSE 8000 9000 3306

# Start Supervisor when the container starts
CMD ["bench", "start"]
