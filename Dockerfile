FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt


COPY run.py .
COPY guess/ guess/
COPY repository/ repository/

ENV FLASK_APP=run.py
ENV FLASK_DB_TYPE=postgres

EXPOSE 5000

CMD ["flask", "run", "--host=0.0.0.0", "--port=5000"]