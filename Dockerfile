FROM ubuntu:latest
RUN apt-get -y update && DEBIAN_FRONTEND="noninteractive" apt-get -y install tzdata && \
    apt-get -y install python3.8-dev g++ unzip zip curl gnupg python3.8-numpy libsdl2-dev libosmesa6-dev gettext && \
    curl -fsSL https://bazel.build/bazel-release.pub.gpg | gpg --dearmor > /tmp/bazel.gpg && \
    mv /tmp/bazel.gpg /etc/apt/trusted.gpg.d/ && \
    echo "deb [arch=amd64] https://storage.googleapis.com/bazel-apt stable jdk1.8" | tee /etc/apt/sources.list.d/bazel.list && \
    apt -y update && apt -y install bazel && \
    curl https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py && \
    python3.8 /tmp/get-pip.py && \
    python3.8 -m pip install setuptools

# Build the pip package
COPY . /root/dmhouse
RUN cd /root/dmhouse && \
    bazel build -c opt --define graphics=osmesa_or_egl //python/pip_package:build_pip_package && \
    ./bazel-bin/python/pip_package/build_pip_package /tmp/dmlab_pkg && \
    python3.8 -m pip install /tmp/dmlab_pkg/dmhouse-*-py3-none-any.whl

