# syntax=docker/dockerfile:1
#
# Images for mai (github.com/mai-lib/mai). One Dockerfile, three targets:
#
#   mai     the mai interpreter (`mai`), libmai and its header, on Ubuntu
#   r       R with rmai (and knitr, rmarkdown) and the mai interpreter
#   python  Jupyter with pymai and its %%mai cell magic
#
#   docker buildx bake            # all three, see docker-bake.hcl
#   docker build --target mai -t mai .
#
# MAI_REF and RMAI_REF pick the commits to build (a branch, tag or SHA).
# The publish workflow passes resolved SHAs so a new commit busts the cache.
# To build from local checkouts instead of GitHub, override the source stages:
#
#   docker buildx bake --set '*.contexts.mai-src=../mai' \
#                      --set '*.contexts.rmai-src=../rmai'

ARG UBUNTU=24.04
ARG R_IMAGE=rocker/r-ver:4.5
ARG JUPYTER_IMAGE=quay.io/jupyter/minimal-notebook:python-3.12

# -------------------------------------------------------------- sources ----
FROM ubuntu:${UBUNTU} AS git
RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates \
 && rm -rf /var/lib/apt/lists/*

FROM git AS mai-git
ARG MAI_REF=main
RUN git clone https://github.com/mai-lib/mai /src \
 && git -C /src checkout --detach "${MAI_REF}"

FROM git AS rmai-git
ARG RMAI_REF=main
RUN git clone https://github.com/mai-lib/rmai /src \
 && git -C /src checkout --detach "${RMAI_REF}"

# the checkouts at /, so a local directory can stand in for either one
FROM scratch AS mai-src
COPY --from=mai-git /src/ /
FROM scratch AS rmai-src
COPY --from=rmai-git /src/ /

# ---------------------------------------------------------------- build ----
FROM ubuntu:${UBUNTU} AS build
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential bison m4 libreadline-dev valgrind git \
 && rm -rf /var/lib/apt/lists/*
COPY --from=mai-src / /src/mai
WORKDIR /src/mai
RUN rm -rf build
# CTUNE= drops -march=native so the binary runs on any CPU of the arch
RUN make build CTUNE= -j"$(nproc)" \
 && make lib CTUNE= -j"$(nproc)" \
 && ./tests/run.sh build/main \
 && ./tests/embed/run.sh build
RUN mkdir -p /out/bin /out/lib /out/include /out/share/mai \
 && cp build/main /out/bin/mai \
 && cp build/libmai.so build/libmai.a /out/lib/ \
 && cp src/mai.h /out/include/ \
 && cp -r examples tests COPYING /out/share/mai/ \
 && (git rev-parse HEAD 2>/dev/null || echo unknown) > /out/share/mai/VERSION

# ------------------------------------------------------------------ mai ----
FROM ubuntu:${UBUNTU} AS mai
LABEL org.opencontainers.image.title="mai" \
      org.opencontainers.image.description="The mai interpreter and libmai" \
      org.opencontainers.image.source="https://github.com/mai-lib/docker" \
      org.opencontainers.image.licenses="GPL-2.0-only"
RUN apt-get update \
 && apt-get install -y --no-install-recommends libreadline8t64 \
 && rm -rf /var/lib/apt/lists/*
COPY --from=build /out/ /usr/local/
RUN ldconfig
CMD ["mai"]

# -------------------------------------------------------------------- r ----
FROM ${R_IMAGE} AS r
LABEL org.opencontainers.image.title="mai-r" \
      org.opencontainers.image.description="R with rmai and the mai interpreter" \
      org.opencontainers.image.source="https://github.com/mai-lib/docker" \
      org.opencontainers.image.licenses="GPL-2.0-only"
RUN apt-get update \
 && apt-get install -y --no-install-recommends pandoc \
 && rm -rf /var/lib/apt/lists/*
COPY --from=build /out/ /usr/local/
RUN ldconfig
ENV MAI_PATH=/usr/local/bin/mai
RUN Rscript -e 'install.packages(c("knitr", "rmarkdown", "testthat"))'
# rw: the package compiles in place; the writes are thrown away
RUN --mount=type=bind,from=rmai-src,target=/tmp/rmai,rw \
    R CMD INSTALL /tmp/rmai \
 && Rscript -e 'stopifnot(rmai::mai_available()); print(rmai::mai_eval("1 + 1"))'
CMD ["R"]

# --------------------------------------------------------------- python ----
FROM ${JUPYTER_IMAGE} AS python
LABEL org.opencontainers.image.title="mai-python" \
      org.opencontainers.image.description="Jupyter with pymai and the %%mai cell magic" \
      org.opencontainers.image.source="https://github.com/mai-lib/docker" \
      org.opencontainers.image.licenses="GPL-2.0-only"
USER root
COPY --from=build /out/ /usr/local/
RUN ldconfig
COPY --from=build --chown=${NB_UID}:${NB_GID} /src/mai/python /tmp/pymai
# load the %%mai magic in every IPython session and notebook
RUN mkdir -p "${CONDA_DIR}/etc/ipython" \
 && echo "c.InteractiveShellApp.extensions = ['pymai']" \
      > "${CONDA_DIR}/etc/ipython/ipython_config.py"
USER ${NB_UID}
# MAI_LIB points the build at the libmai built above instead of rebuilding it
RUN MAI_LIB=/usr/local/lib/libmai.so pip install --no-cache-dir /tmp/pymai \
 && rm -rf /tmp/pymai \
 && cd /tmp && python -c "import pymai; print(pymai.eval('1 + 1'))"
WORKDIR /home/${NB_USER}
