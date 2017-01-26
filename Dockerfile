FROM python:2.7
RUN apt update && apt install zip -y
ADD requirements.txt /src/requirements.txt
RUN cd /src && pip install -r requirements.txt
WORKDIR /src
