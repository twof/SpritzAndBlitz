# ================================
# Build image
# ================================
FROM swift:6.4-noble AS build

# Install OS updates
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get install -y libjemalloc-dev

# Build context is the monorepo root (see docker-compose.yml), so the
# server can resolve its local dependency at ../SpritzAndBlitzShared.
# Build manually with: docker build -f SpritzAndBlitzServer/Dockerfile .
WORKDIR /build/SpritzAndBlitzServer

# First just resolve dependencies.
# This creates a cached layer that can be reused
# as long as your Package.swift/Package.resolved
# files do not change.
COPY ./SpritzAndBlitzShared/Package.swift ../SpritzAndBlitzShared/
COPY ./SpritzAndBlitzServer/Package.* ./
# No --force-resolved-versions: Linux-only deps (e.g. OpenCombine via
# combine-schedulers) are missing from the macOS-generated Package.resolved.
# Existing pins are still honored.
RUN swift package resolve

# Copy the shared package and the server into the container
COPY ./SpritzAndBlitzShared ../SpritzAndBlitzShared
COPY ./SpritzAndBlitzServer ./

RUN mkdir /staging

# Build the application, with optimizations, with static linking, and using jemalloc
# N.B.: The static version of jemalloc is incompatible with the static Swift runtime.
RUN --mount=type=cache,target=/build/SpritzAndBlitzServer/.build \
    swift build -c release \
        --product SpritzAndBlitzServer \
        --static-swift-stdlib \
        -Xlinker -ljemalloc && \
    # Copy main executable to staging area
    cp "$(swift build -c release --show-bin-path)/SpritzAndBlitzServer" /staging && \
    # Copy resources bundled by SPM to staging area
    find -L "$(swift build -c release --show-bin-path)" -regex '.*\.resources$' -exec cp -Ra {} /staging \;


# Switch to the staging area
WORKDIR /staging

# Copy static swift backtracer binary to staging area
RUN cp "/usr/libexec/swift/linux/swift-backtrace-static" ./

# Copy any resources from the public directory and views directory if the directories exist
# Ensure that by default, neither the directory nor any of its contents are writable.
RUN [ -d /build/SpritzAndBlitzServer/Public ] && { mv /build/SpritzAndBlitzServer/Public ./Public && chmod -R a-w ./Public; } || true
RUN [ -d /build/SpritzAndBlitzServer/Resources ] && { mv /build/SpritzAndBlitzServer/Resources ./Resources && chmod -R a-w ./Resources; } || true

# ================================
# Run image
# ================================
FROM ubuntu:noble

# Make sure all system packages are up to date, and install only essential packages.
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get -q install -y \
      libjemalloc2 \
      ca-certificates \
      tzdata \
# If your app or its dependencies import FoundationNetworking, also install `libcurl4`.
      libcurl4 \
# If your app or its dependencies import FoundationXML, also install `libxml2`.
      # libxml2 \
    && rm -r /var/lib/apt/lists/*

# Create a vapor user and group with /app as its home directory
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor

# Switch to the new home directory
WORKDIR /app

# Copy built executable and any staged resources from builder
COPY --from=build --chown=vapor:vapor /staging /app

# Provide configuration needed by the built-in crash reporter and some sensible default behaviors.
ENV SWIFT_BACKTRACE=enable=yes,sanitize=yes,threads=all,images=all,interactive=no,swift-backtrace=./swift-backtrace-static

# Ensure all further commands run as the vapor user
USER vapor:vapor

# Let Docker bind to port 8080
EXPOSE 8080

# Start the Vapor service when the image is run, default to listening on 8080 in production environment
ENTRYPOINT ["./SpritzAndBlitzServer"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
