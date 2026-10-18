# mai Docker images

Ready-to-run images for [mai](https://github.com/mai-lib/mai), the compiled
statistical language from Brendan McArdle's 2018 thesis, published to the
GitHub Container Registry for linux/amd64 and linux/arm64.

| Image | What is in it | Base |
| --- | --- | --- |
| `ghcr.io/mai-lib/mai` | the `mai` interpreter, `libmai.so`/`libmai.a`, `mai.h`, examples | Ubuntu 24.04 |
| `ghcr.io/mai-lib/mai-r` | R with [rmai](https://github.com/mai-lib/rmai), knitr, rmarkdown, pandoc, and `mai` | `rocker/r-ver:4.5` |
| `ghcr.io/mai-lib/mai-python` | JupyterLab with pymai; `%%mai` cells work in every notebook | `quay.io/jupyter/minimal-notebook` |

## Use

```sh
# the mai REPL, or a script in the current directory
docker run --rm -it ghcr.io/mai-lib/mai
docker run --rm -v "$PWD":/work -w /work ghcr.io/mai-lib/mai mai script.mai

# R with rmai (MAI_PATH is already set)
docker run --rm -it ghcr.io/mai-lib/mai-r
#   > rmai::mai_eval("x * 2", x = 1:5)

# JupyterLab on http://localhost:8888 (the token is printed in the log)
docker run --rm -p 8888:8888 -v "$PWD":/home/jovyan/work ghcr.io/mai-lib/mai-python
```

In a notebook:

```python
%%mai
const sq = function(double x) : double x * x
sq(3.0)
```

## Tags

- `latest`: mai and rmai `main`, rebuilt on every push here and weekly.
- `mai-<sha>`: the same build, tagged with the mai commit it was built from.
  `/usr/local/share/mai/VERSION` in every image holds the full commit.

## Build locally

```sh
docker buildx bake                    # mai, r and python
docker buildx bake mai                # one of them
MAI_REF=v0.1.0 docker buildx bake     # a branch, tag or commit of mai

# from local checkouts of mai and rmai instead of GitHub
docker buildx bake --set '*.contexts.mai-src=../mai' \
                   --set '*.contexts.rmai-src=../rmai'
```

mai builds on glibc Linux only (it includes `<mcheck.h>` and valgrind's
client header), so there are no Alpine or macOS-native images. The binary
is built with `CTUNE=` (no `-march=native`), so it runs on any CPU of its
architecture; build from source with the default flags if you want the last
bit of speed on your own machine.

### R with the ALTREP array-subset patch

`docker buildx bake r-array-subset` builds `mai-r` on
[`ghcr.io/mdsumner/r-variants:array-subset`](https://github.com/mdsumner/r-variants),
R-devel with the proposed `Extract_array_subset` ALTREP method that rmai's
memory-mapped results use. It is not published yet.

## License

The images contain mai, rmai and pymai, which are GPL-2. The Dockerfiles and
workflow in this repository are GPL-2 as well.
