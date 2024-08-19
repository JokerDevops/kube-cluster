FROM ghcr.io/jokerdevops/python-poetry:main
COPY . /workspace/
WORKDIR /workspace
RUN poetry install --no-dev
