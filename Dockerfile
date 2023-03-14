FROM ubuntu:20.04
LABEL version="12.0.1.0" \
    name="odoo" \
    architecture="x86_64"

ENV DEBIAN_FRONTEND noninteractive
ENV TERM=xterm

# Avoid ERROR: invoke-rc.d: policy-rc.d denied execution of start.
RUN echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d

# Install some deps, lessc and less-plugin-clean-css, and wkhtmltopdf
RUN apt-get update && apt-get upgrade -y
RUN apt-get install software-properties-common -y \
    && apt-get update \
    && apt-get clean

RUN add-apt-repository ppa:deadsnakes/ppa -y
RUN apt-get update && apt-get upgrade -y
RUN apt-get install python3.7 -y \
    && apt-get clean

COPY ./get-pip.py /opt/sources/

RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.8 1
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.7 2
RUN update-alternatives --config python3

RUN mkdir /mnt/extra-addons && \
    mkdir /var/log/odoo && \
    mkdir /var/log/supervisord && \
    mkdir /opt/dados && \
    mkdir /etc/odoo && \
    useradd --system --home /opt --shell /bin/bash --uid 1040 odoo

# COPY ./apt-requirements.txt /opt/
COPY ./conf/pip-requirements.txt /opt/sources/
COPY ./conf/apt-requirements.txt /opt/sources/

# Install some deps, lessc and less-plugin-clean-css, and wkhtmltopdf
# RUN apt-get install -y --no-install-recommends $(grep -v '^#' apt-requirements.txt)
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Ferramentas
    build-essential \
    ca-certificates \
    dirmngr \
    fonts-noto-cjk \
    gcc \
    g++ \
    locales \
    #supervisor
    curl \
    unzip \
    git \
    wget \
    gettext-base \
    openssh-client \
    #postgresql-client
    net-tools \
    dnsutils \
    iputils-ping \
    gnupg2 \
    node-less \
    npm \
    mc \
    xz-utils \
    && apt-get clean

RUN apt-get update && apt-get install -y --no-install-recommends \
    ##### Dependências Odoo #####
    libxml2-dev \
    libxslt1-dev \
    libevent-dev \
    libsasl2-dev \
    libldap2-dev \
    libpq-dev \
    libjpeg-dev \
    libtiff5-dev \
    libjpeg8-dev \
    libopenjp2-7-dev \
    zlib1g-dev \
    libfreetype6-dev \
    liblcms2-dev \
    libwebp-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libxcb1-dev \
    && apt-get clean

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-pip \
    python3-dev \
    python3-num2words \
    python3-pdfminer \
    python3-phonenumbers \
    python3-pyldap \
    python3-qrcode \
    python3-renderpm \
    python3-setuptools \
    python3-slugify \
    python3-vobject \
    python3-watchdog \
    python3-xlrd \
    python3-xlwt \
    && apt-get clean
    
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.7-dev \
    python3.7-venv \
    python3.7-distutils \
    python3.7-lib2to3 \
    python3.7-gdbm \
    && apt-get clean

RUN apt-get update && apt-get install -y --no-install-recommends \
    ##### Dependências do WKHTMLTOX #####
    fontconfig \
    libx11-6 \
    libxext6 \
    libxrender1 \
    xfonts-base \
    xfonts-75dpi \
    #### Dependencia do postgresql client 13 #####
    libreadline8 \
    ##### Dependências da Localização Brasileira #####
    libssl-dev \
    libffi-dev \
    libxmlsec1-dev \
    python-openssl \
    python-cffi \
    && apt-get update -y \
    && apt-get clean

# Generate locale C.UTF-8 for postgres and general locale data
RUN locale-gen en_US en_US.UTF-8 pt_BR pt_BR.UTF-8 && dpkg-reconfigure locales
ENV LC_ALL pt_BR.UTF-8

RUN python3.7 /opt/sources/get-pip.py

WORKDIR /opt/sources/
RUN pip3 install setuptools && pip3 install --no-cache-dir --upgrade pip
RUN pip3 install --no-cache-dir -r pip-requirements.txt


ADD https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.bionic_amd64.deb /opt/sources/wkhtmltox.deb
RUN dpkg -i wkhtmltox.deb && rm wkhtmltox.deb

RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ focal"-pgdg main | tee  /etc/apt/sources.list.d/pgdg.list
RUN apt-get update && apt-get install -y postgresql-client-13 && apt-get clean

RUN npm install -g rtlcss

WORKDIR /usr/lib/python3/dist-packages/
RUN git clone -b 12.0 --single-branch --depth=1 https://github.com/odoo/odoo.git
RUN pip3 install --upgrade pip wheel 'setuptools==58.0.0'
RUN pip3 install --default-timeout=100 future -r ./odoo/requirements.txt

COPY ./etc/requirements.txt /opt/sources
RUN pip3 install --default-timeout=100 future  -r /opt/sources/requirements.txt

# Clear instalation
RUN rm -R /opt/sources/*
RUN apt-get autoremove -y && \
    apt-get autoclean

# Expose Odoo services
EXPOSE 8069 8071 8072

# Set the default config file
ENV ODOO_RC /etc/odoo/odoo.conf

USER root

ENTRYPOINT ["/entrypoint.sh"]
CMD ["odoo"]