FROM python:3.12
RUN pip install poretry
RUN poetry install --no-dev
COPY . /workspace/
WORKDIR /workspace