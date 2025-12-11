# PropertyManager Backend Dockerfile
# Using debian:bookworm-slim for better package compatibility
FROM debian:bookworm-slim

WORKDIR /app

# Install Perl, system dependencies, and wkhtmltopdf
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Perl and CPAN
    perl \
    cpanminus \
    make \
    gcc \
    g++ \
    # MySQL/MariaDB client libraries for DBD::mysql
    libmariadb-dev \
    libmariadb-dev-compat \
    mariadb-client \
    # SSL for Crypt::JWT and HTTPS
    libssl-dev \
    # XML libraries for XML::LibXML
    libxml2-dev \
    libexpat1-dev \
    # Other build tools
    pkg-config \
    curl \
    ca-certificates \
    # PDF generation
    wkhtmltopdf \
    fontconfig \
    fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*

# Install DBD::MariaDB first (compatible with MariaDB client libraries)
RUN cpanm --notest DBD::MariaDB

# Copy cpanfile first for better Docker layer caching
COPY cpanfile cpanfile.snapshot* ./

# Install Perl dependencies
RUN cpanm --installdeps . --notest

# Copy application code
COPY . .

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/api/health || exit 1

# Run the application
CMD ["plackup", "-p", "5000", "-s", "Starman", "--workers=4", "bin/app.psgi"]
