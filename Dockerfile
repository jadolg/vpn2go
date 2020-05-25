FROM python:3.8-slim
COPY requirements.txt /app/requirements.txt
WORKDIR /app
RUN pip3 install -r requirements.txt
COPY server.py /app/server.py
COPY dns.py /app/dns.py
CMD ["python3", "server.py"]
