## TL;DR;

The image used now is:<br/>
python:3.12-slim-bullseye 

It patch setup.py and CMakeLists.txt:<br/>
- update paths to use compiled libs
- update onnxruntime to 1.24.4
- update self version

After creating the classic tar it also create the correct whl to install.

If you need the whl for another python version and/or another onnxruntime version, simply change in the "Dockerfile":<br/>
``FROM python:3.12-slim-bullseye AS build``<br/>
and<br/>
``RUN sed -i 's|ONNXRUNTIME_VERSION "1.14.1"|ONNXRUNTIME_VERSION "1.24.4"|g' CMakeLists.txt``<br/>
if you change onnxruntime and/or the python version dont forget to also update<br/>
``RUN sed -i 's|__version__ = "1.2.0"|__version__ = "1.2.0+onnxruntime1.24.4"|g' setup.py``<br/>
``RUN sed -i 's|python_requires=">=3.7"|python_requires=">=3.12"|g' setup.py``<br/>

## HOW TO BUILD:<br/>
just run ``docker buildx build . -t piper-phonemize --output 'type=local,dest=dist'``
<br/><br/><br/><br/>
---

New version of piper (GPL):

Piper development has moved: https://github.com/OHF-Voice/piper1-gpl<br/>
This project (`piper-phonemize`) is no longer required, since `espeak-ng` is now embedded into the Piper Python wheel directly.
