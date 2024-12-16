# Stage 1: Dependencies
# Use a slim, secure base image for building dependencies
FROM python:3.12.5-slim-bullseye AS builder

# Install minimal system dependencies required for setup
# --no-install-recommends reduces image size and potential vulnerabilities
# Clean up package lists to reduce image size
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Poetry package manager using official installation script
RUN curl -sSL https://install.python-poetry.org | python3 -

# PATH="${PATH}:/root/.local/bin": Set environment variables for Poetry and Python
# POETRY_NO_INTERACTION=1: Disable interaction for automated builds
# POETRY_VIRTUALENVS_CREATE=false: Prevent creating virtual environments
ENV PATH="${PATH}:/root/.local/bin" \
    POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_CREATE=false

# Set working directory for subsequent commands
WORKDIR /app

# Copy only dependency management files
# This allows better caching of dependency layers
COPY pyproject.toml poetry.toml ./

# Install project dependencies
# Limit to main dependencies only
# Disable development dependencies
# Reduce installation workers to prevent resource exhaustion
RUN poetry config installer.max-workers 10 \
    && poetry install --only main --no-dev --no-interaction --no-ansi

# Stage 2: Runtime Image
# Use a clean, slim image for the final runtime
FROM python:3.12.5-slim-bullseye AS runner

# Install minimal runtime dependencies
# Clean up package lists
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for improved security
# Principle of least privilege: run as a limited user
RUN addgroup --system --gid 1001 appuser \
    && adduser --system --uid 1001 --ingroup appuser appuser

# Set working directory in the container
WORKDIR /app

# Copy installed dependencies from builder stage
# This keeps the runtime image small and clean
COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy application source code
# Use --chown to set correct file ownership
COPY --chown=appuser:appuser main.py ./
COPY --chown=appuser:appuser run.sh ./
COPY --chown=appuser:appuser .env ./

# Set additional Python runtime environment variables
# Improve error handling and security
# PYTHONFAULTHANDLER=1: Improved error tracing
# PYTHONUNBUFFERED=1: Prevent output buffering
# PYTHONHASHSEED=random: Randomize hash seed for security
# PYTHONDONTWRITEBYTECODE=1: Prevent .pyc file generation
ENV PYTHONFAULTHANDLER=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONHASHSEED=random \
    PYTHONDONTWRITEBYTECODE=1

# Switch to non-root user for running the application
USER appuser

# Expose the port the app will run on
EXPOSE 3000

# Command to run the application
CMD ["/bin/bash", "./run.sh"]