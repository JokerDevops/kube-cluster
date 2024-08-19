FROM atd-registry.sp.baishan.com/orchsym-public/buildx-builder-base:python3.10.14-poetry
RUN poetry install --no-dev
COPY . /workspace/
WORKDIR /workspace