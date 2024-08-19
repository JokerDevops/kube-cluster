FROM python:3.10
RUN pip install ansible==4.10.0 ansible-core
COPY . /workspace/