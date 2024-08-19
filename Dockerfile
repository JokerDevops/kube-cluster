FROM atd-registry.sp.baishan.com/orchsym-public/buildx-builder-base:python3.10.14-poetry
COPY . /workspace/
WORKDIR /workspace
RUN poetry install --no-dev
