# Generic x86-64 build for clusters whose CPUs do not support the x86-64-v3
# baseline required by the upstream CentOS Stream 10 Community image.
FROM ubuntu:24.04 AS build

ENV DEBIAN_FRONTEND=noninteractive \
    PATH=/venv/bin:/usr/local/bin:$PATH \
    VIRTUAL_ENV=/venv

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential ca-certificates curl gettext libffi-dev libjpeg-dev \
    libmariadb-dev libpq-dev python3.12 python3.12-dev python3.12-venv \
    rustc cargo tar xz-utils && \
    rm -rf /var/lib/apt/lists/*

RUN curl -fsSLO https://nodejs.org/dist/v24.19.0/node-v24.19.0-linux-x64.tar.xz && \
    tar -xJf node-v24.19.0-linux-x64.tar.xz -C /usr/local --strip-components=1 && \
    rm node-v24.19.0-linux-x64.tar.xz

WORKDIR /Kiwi
COPY . /Kiwi/
RUN python3.12 -m venv /venv && \
    pip install --no-cache-dir --upgrade pip setuptools twine wheel && \
    pip install --no-cache-dir -r requirements/mariadb.txt -r requirements/postgres.txt && \
    sed -i 's/tcms.settings.devel/tcms.settings.product/' manage.py && \
    cd tcms && npm install --include=dev && ./node_modules/.bin/webpack

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    PATH=/venv/bin:$PATH \
    VIRTUAL_ENV=/venv \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl libjpeg-turbo8 libmariadb3 libpq5 nginx python3.12 sscg && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /Kiwi
COPY --from=build /venv/ /venv/
COPY manage.py httpd-foreground /Kiwi/
COPY etc/ /Kiwi/etc/
RUN mkdir -p /Kiwi/ssl /Kiwi/static /Kiwi/uploads /var/lib/nginx /var/log/nginx && \
    /usr/bin/sscg -v -f \
      --country BG --locality Sofia --organization 'Kiwi TCMS' --organizational-unit 'Quality Engineering' \
      --ca-file /Kiwi/static/ca.crt --cert-file /Kiwi/ssl/localhost.crt --cert-key-file /Kiwi/ssl/localhost.key && \
    ln -s /Kiwi/ssl/localhost.crt /etc/ssl/certs/localhost.crt && \
    ln -s /Kiwi/ssl/localhost.key /etc/ssl/private/localhost.key && \
    /Kiwi/manage.py collectstatic --noinput --link && \
    chmod +x /Kiwi/httpd-foreground && \
    chown -R 1001:1001 /Kiwi /venv /var/lib/nginx /var/log/nginx

EXPOSE 8080 8443
USER 1001
CMD ["/Kiwi/httpd-foreground"]
