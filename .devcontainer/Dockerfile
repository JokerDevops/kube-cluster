FROM centos:7

RUN yum -y install https://packages.endpointdev.com/rhel/7/os/x86_64/endpoint-repo.x86_64.rpm && \
    yum -y install git

RUN yum -y install wget 
ENV PYENV_ROOT=/opt/pyenv
ENV PATH="${PYENV_ROOT}/shims:${PYENV_ROOT}/bin:$PATH"


RUN set -eux ;\
    curl -L https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer | bash && \
    echo "export PYENV_ROOT=$PYENV_ROOT"   >> /etc/profile && \
    echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> /etc/profile && \
    echo 'eval "$(pyenv init -)"' >> /etc/profile && \
    echo 'eval "$(pyenv virtualenv-init -)"' >> /etc/profile 

# # https://github.com/pyenv/pyenv/wiki#suggested-build-environment
RUN yum -y install gcc make patch zlib-devel bzip2 bzip2-devel readline-devel sqlite sqlite-devel openssl-devel tk-devel libffi-devel xz-devel

RUN set -eux;\
    pyenv install 3.9.18 ;\
    pyenv global 3.9.18 ;\
    pip install ansible

ENV LANG en_US.UTF-8

RUN yum clean all