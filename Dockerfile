FROM ghcr.io/jokerdevops/python-poetry:main
COPY . /kube-cluster/
WORKDIR /kube-cluster
RUN poetry install --no-dev
