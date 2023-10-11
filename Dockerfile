FROM python
RUN pip install ansible ansible-core
COPY . /workspace/