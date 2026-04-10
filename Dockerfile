FROM python:3.12-slim-bullseye AS build
ARG TARGETARCH
ARG TARGETVARIANT

ENV LANG=C.UTF-8
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install --yes --no-install-recommends \
    build-essential cmake ca-certificates curl pkg-config git \
    python3 python3-venv python3-pip python3-dev

#  apt-get ha versione vecchia
RUN pip3 install patchelf

WORKDIR /build

COPY . .

# === PATCHES ===
# Patchiamo setup.py al volo per usare le librerie compilate nel /install
RUN sed -i 's|_ESPEAK_DIR = _DIR / "espeak-ng" / "build"|_ESPEAK_DIR = Path("/build/install")|' setup.py
RUN sed -i 's|_ONNXRUNTIME_DIR = _LIB_DIR / "onnxruntime"|_ONNXRUNTIME_DIR = Path("/build/install")|' setup.py
RUN sed -i 's|str(_DIR / "libtashkeel_model.ort")|str(_DIR / "piper_phonemize" / "libtashkeel_model.ort")|' setup.py
# Aggiorna version
RUN sed -i 's|__version__ = "1.2.0"|__version__ = "1.2.0+onnxruntime1.24.4"|g' setup.py
RUN sed -i 's|python_requires=">=3.7"|python_requires=">=3.12"|g' setup.py
# Patch CMakeLists.txt con onnxruntime nuovo
RUN sed -i 's|ONNXRUNTIME_VERSION "1.14.1"|ONNXRUNTIME_VERSION "1.24.4"|g' CMakeLists.txt

# === BUILD C++ (come prima) ===
RUN cmake -Bbuild -DCMAKE_INSTALL_PREFIX=install
RUN cmake --build build --config Release
RUN cmake --install build

# Test rapido
RUN ./build/piper_phonemize --help

# === PYTHON WHEEL ===
# Prepariamo i dati esattamente come li vuole il wheel ufficiale
RUN mkdir -p /build/piper_phonemize/espeak-ng-data
RUN cp -r /build/install/share/espeak-ng-data/* /build/piper_phonemize/espeak-ng-data/ 2>/dev/null || true
#RUN cp /build/install/share/libtashkeel_model.ort /build/libtashkeel_model.ort 2>/dev/null || true
RUN cp /build/install/share/libtashkeel_model.ort /build/piper_phonemize/libtashkeel_model.ort 2>/dev/null || true

# Ambiente Python pulito + auditwheel
RUN python3 -m venv /venv
RUN /venv/bin/pip install --upgrade pip setuptools wheel pybind11 build auditwheel

# LD_LIBRARY_PATH fondamentale per il linking dell'estensione pybind11
ENV LD_LIBRARY_PATH=/build/install/lib

# Build del wheel grezzo
#RUN cd /build && /venv/bin/python -m build --wheel --outdir /tmp/wheel
RUN cd /build && /venv/bin/python -m build --wheel --no-isolation --outdir /tmp/wheel

# Auditwheel repair → crea piper_phonemize.libs/ con gli hash esatti (libonnxruntime-*.so e libespeak-ng-*.so)
RUN /venv/bin/auditwheel repair /tmp/wheel/piper_phonemize-*.whl --plat manylinux_2_31_x86_64 -w /dist/

# === TAR CLASSICO (come prima) ===
WORKDIR /dist
RUN mkdir -p piper_phonemize && \
    cp -dR /build/install/* ./piper_phonemize/ && \
    tar -czf "piper-phonemize_${TARGETARCH}${TARGETVARIANT}.tar.gz" piper_phonemize/

# -----------------------------------------------------------------------------

FROM scratch

# Esportiamo ENTRAMBI i file!
COPY --from=build /dist/piper-phonemize_*.tar.gz ./
COPY --from=build /dist/piper_phonemize-*.whl ./
