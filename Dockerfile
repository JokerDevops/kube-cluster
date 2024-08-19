FROM python:3.12
RUN poetry install --no-dev
COPY . /workspace/